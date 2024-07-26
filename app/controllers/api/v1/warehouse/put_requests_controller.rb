class Api::V1::Warehouse::PutRequestsController < ApplicationController
  before_action :set_put_request, only: [:show, :update, :destroy, :add_items, :mark_as_not_found]

  def index
    set_pagination_params(params)
    @put_requests = if params[:dispatch_requests].eql?("true")
      PutRequest.dispatch_requests
    else
      PutRequest.putaway_requests
    end
    @put_requests = @put_requests.includes(:distribution_center, :request_items, :users).order(id: :desc)
    filter_requests

    @put_requests = @put_requests.page(@current_page).per(@per_page)
    render json: @put_requests, meta: pagination_meta(@put_requests)
  end

  def show
    render json: @put_request, include: "request_items", show_items: true
  end

  def create
    ActiveRecord::Base.transaction do
      @put_request = PutRequest.new(put_request_params)
      @put_request.status = "pending"
      @put_request.save!
      
      pending_inventory_ids = RequestItem.joins(:put_request).where("put_requests.status IN (?) OR request_items.status = ?", [1, 2], 3).pluck(:inventory_id)
      raise CustomErrors.new "Request has been created for few items. Please refresh the screen!" if (params[:put_request][:inventory_ids] & pending_inventory_ids).present?
      
      @put_request.assign_users(params[:put_request][:assignee_ids])
      @put_request.update_request_items(inventory_ids: params[:put_request][:inventory_ids], from_dispatch: false)
      
      request_type = @put_request.request_type_put_away? ? @put_request.put_away_reason&.titleize : "PickUp"
      message = "#{@put_request.request_id} #{request_type} request successfully created."
      render json: { put_request: @put_request, message: message}, status: :created
    end
  end

  def update
    begin
      ActiveRecord::Base.transaction do
        raise CustomErrors.new "#{@put_request.status&.titleize} requests can not be updated." unless @put_request.status_pending?
        
        pending_inventory_ids = RequestItem.joins(:put_request).where("put_requests.status IN (?) OR request_items.status = ?", [1, 2], 3).pluck(:inventory_id)
        existing_inventory_ids = @put_request.request_items.pluck(:inventory_id)
        new_inventory_ids = params[:put_request][:inventory_ids] - existing_inventory_ids

        raise CustomErrors.new "Request has been created for few items. Please refresh the screen!" if (new_inventory_ids & pending_inventory_ids).present?

        @put_request.update!(put_request_params)
        @put_request.assign_users(params[:put_request][:assignee_ids])
        if @put_request.is_dispatch_item?
          @put_request.update_request_items(warehouse_order_item_ids: params[:put_request][:inventory_ids], from_dispatch: @put_request.is_dispatch_item?)
        else
          @put_request.update_request_items(inventory_ids: params[:put_request][:inventory_ids])
        end

        render json: @put_request
      end
    rescue  Exception => message
      render json: { error: message.to_s }, status: 500
    end
  end
  
  def cancel_request
    ActiveRecord::Base.transaction do
      requests = PutRequest.where(id: params[:request_ids])
      raise CustomErrors.new "Invalid Request IDs" unless requests.present?
      
      requests.each do |request|
        request.update(status: "cancelled")
        request.update_cancelled_items
      end
      message = "Request #{requests.pluck(:request_id).join(", ")} successfully cancelled"
      render json: {status: :ok, message: message}
    end
  end
  
  def destroy
    ActiveRecord::Base.transaction do
      @put_request.update_cancelled_items
      
      @put_request.destroy
      render json: {status: :ok}
    end
  end
  
  def location_users
    distribution_center = DistributionCenter.find_by(id: params[:distribution_center_id])
    raise CustomErrors.new "Invalid Location!" unless distribution_center.present?
    
    users = distribution_center.users.distinct.as_json(only: [:id, :username])
    
    render json: {users: users}
  end
  
  def update_assignee
    ActiveRecord::Base.transaction do
      put_requests = PutRequest.where(id: params[:request_ids])
      raise CustomErrors.new "Invalid Request ID" unless put_requests.present?
      
      put_requests.each do |put_request|
        put_request.assign_users(params[:assignee_ids])
      end

      render json: {status: :ok}
    end
  end
  
  def add_items
    set_pagination_params(params)
    distribution_center = @put_request.distribution_center
    if @put_request.request_type_put_away?
      if @put_request.put_away_reason_open_putaway?
        @inventories = distribution_center.inventories.joins(:sub_location).where("sub_locations.location_type = ?", 1).order(updated_at: :desc)
      else
        @inventories = distribution_center.inventories.not_inwarded.where(sub_location_id: nil).order(updated_at: :desc)
      end
    else
      @inventories = distribution_center.inventories.where(is_putaway_inwarded: true)
      @inventories = @inventories.where(disposition: @put_request.disposition) if @put_request.disposition.present?
    end
    # pending request items
    inventory_ids = RequestItem.joins(:put_request).where("put_requests.status IN (?) OR request_items.status = ?", [1, 2], 3).pluck(:inventory_id)
    @inventories = @inventories.includes(:distribution_center, :sub_location).where.not(id: inventory_ids)
    
    @inventories = @inventories.filter_by_tag_number(params[:search]) if params[:search].present?
    @inventories = @inventories.page(@current_page).per(@per_page)
    render json: @inventories, each_serializer: PutAwaySerializer, meta: pagination_meta(@inventories)
  end
  
  def mark_as_not_found
    items = @put_request.request_items.where(id: params[:item_ids])
    raise CustomErrors.new "Invalid Item ID" if items.blank?
    
    items_count = items.count
    items.update_all(status: "not_found")
    
    pending_items = @put_request.request_items.where(status: [1,2])
    @put_request.update!(status: "completed", completed_at: Time.now) unless pending_items.present?
    
    render json: { message: "#{items_count} item marked as 'Not Found' successfully." }
  end
  
  def filters_data
    request_types = PutRequest.request_types.slice("pick_up", "packaging").map{|i| {id: i[0], name: i[0].titleize} }
    statuses = PutRequest.statuses.except("cancelled").map{|i| {id: i[0], name: i[0].titleize} }
    
    render json: {request_types: request_types, statuses: statuses}
  end

  private
  
    def set_put_request
      @put_request = PutRequest.find_by(id: params[:id])
    end

    def put_request_params
      params.require(:put_request).permit(:distribution_center_id, :request_type, :put_away_reason, :pick_up_reason, :disposition)
    end
    
    def filter_requests
      @put_requests = @put_requests.where("completed_at > ? OR status IN (?)", 1.week.ago, [1,2])
      dc_ids = @distribution_center.present? ? [@distribution_center.id] : current_user.distribution_centers.select(:id)
      @put_requests = @put_requests.where(distribution_center_id: dc_ids)
      @put_requests = @put_requests.search_by_request_id(params[:request_id]) if params[:request_id].present?
      @put_requests = @put_requests.where(status: params[:status]) if params[:status].present?
      @put_requests = @put_requests.where(request_type: params[:request_type]) if params[:request_type].present?
    end
end
