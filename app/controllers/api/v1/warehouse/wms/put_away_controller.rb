class Api::V1::Warehouse::Wms::PutAwayController < ApplicationController
  before_action :set_put_request, only: [:show, :get_sub_locations, :update_sub_location, :add_toat, :submit_request, :update_pick_up]
  
  def index
    set_pagination_params(params)
    put_requests = current_user.put_requests.putaway_requests.where(status: ["pending", "in_progress"]).order(updated_at: :desc)
    put_requests = put_requests.search_by_request_id(params[:search]) if params[:search].present?
    put_requests = put_requests.page(@current_page).per(@per_page)
    data = put_requests.map{ |put_request|
      {id: put_request.id, request_id: put_request.request_id, request_type: put_request.request_type&.titleize, status: put_request.status&.titleize}
    }
    
    render json: {put_requests: data, meta: pagination_meta(put_requests)}
  end
  
  def show
    data = {id: @put_request.id, request_id: @put_request.request_id, request_type: @put_request.request_type&.titleize, status: @put_request.status&.titleize}
    data[:request_reason] = @put_request.request_type_put_away? ? @put_request.put_away_reason&.titleize : @put_request.pick_up_reason&.titleize
    data[:is_pickup_done] = @put_request.is_pickup_done? if @put_request.request_type_pick_up?
    data["items"] = @put_request.get_items_and_boxes
    
    render json: {put_request: data}
  end
  
  def get_sub_locations
    raise CustomErrors.new "Please scan the Item/Box Tag ID." if (params[:tag_number].blank? and params[:box_no].blank?)
    
    if params[:tag_number].present?
      inventory = Inventory.find_by(tag_number: params[:tag_number])
      raise CustomErrors.new "Invalid Tag ID!" unless inventory.present?
      sub_locations = inventory.get_suggested_sublocations(@put_request.distribution_center)
    else
      request_items = @put_request.request_items.where(box_no: params[:box_no])
      raise CustomErrors.new "Invalid Box ID!" unless request_items.present?
      
      sub_locations = @put_request.distribution_center.sub_locations
    end
    
    data = sub_locations.all.as_json(only: [:id, :code])
    render json: {sub_locations: data}
  end
  
  def update_sub_location
    distribution_center = @put_request.distribution_center
    sub_location = distribution_center.sub_locations.find_by(code: params[:location_code])
    raise CustomErrors.new "Invalid Location Code!" unless sub_location.present?
    
    @put_request.status_in_progress! if @put_request.status_pending?
    
    if params[:request_type] == "pick_up"
      item = @put_request.request_items.find_by(id: params[:item_id])
      raise CustomErrors.new "Invalid Item Tag ID!" unless item.present?
      
      inventory = item.inventory
      item.update!(status: "pending_putaway")
      inventory.update!(sub_location_id: nil)
    else
      if params[:item_type] == "box"
        items = @put_request.request_items.where(box_no: params[:box_no])
        raise CustomErrors.new "Invalid Box ID!" unless items.present?
      else
        items = @put_request.request_items.where(id: params[:item_id])
        raise CustomErrors.new "Invalid Item Tag ID!" unless items.present?
        
        # validate_sub_location(items.first.inventory, sub_location)
      end
      
      inventory_ids = items.pluck(:inventory_id)
      inventories = Inventory.where(id: inventory_ids)
      
      items.update_all(to_sub_location_id: sub_location.id, status: 'completed')
      inventories.update_all(sub_location_id: sub_location.id, is_putaway_inwarded: true)
      
      @put_request.reload
      pending_items = @put_request.request_items.where(status: [1,2])
      @put_request.update!(status: "completed", completed_at: Time.now) unless pending_items.present?
    end
    
    render json: {}
  end
  
  def add_toat
    raise CustomErrors.new "Please enter Toat ID!" unless params[:box_no].present?
    
    inventory_ids = Inventory.where(tag_number: params[:tag_numbers])
    request_items = @put_request.request_items.where(inventory_id: inventory_ids)
    request_items.update_all(box_no: params[:box_no])
    
    render json: {}
  end
  
  def submit_request
    # picked_up_items = @put_request.request_items.status_picked
    # raise CustomErrors.new "Please put away all the picked items!" if picked_up_items.present?
    
    # not_found_items = @put_request.request_items.where(status: [nil, "not_found"])
    # not_found_items_count = not_found_items.count
    # not_found_items.update_all(status: "not_found")
    # message += " #{not_found_items_count} item marked as not found." if not_found_items_count > 0
    
    pending_items = @put_request.request_items.where(status: [1,2])
    if pending_items.present?
      completed_items = @put_request.request_items.status_completed.count
      all_items = @put_request.request_items.count
      action = @put_request.request_type_put_away? ? "putaway" : "picked up"
      message = "#{completed_items}/#{all_items} Tag/Box IDs successfully #{action}."
    else
      # @put_request.update!(status: "completed", completed_at: Time.now) unless @put_request.status_completed?
      
      req_type = @put_request.request_type_put_away? ? "PutAway" : "PickUp"
      message = "#{req_type} request #{@put_request.request_id} is successfully closed."
    end
    
    render json: { message: message }
  end
  
  def update_pick_up
    not_found_items = @put_request.request_items.where(status: [nil, "not_found"])
    not_found_items_count = not_found_items.count
    not_found_items.update_all(status: "not_found")
    
    @put_request.update!(is_pickup_done: true)
    if not_found_items_count > 0
      message = "#{not_found_items_count} item marked as not found in #{@put_request.request_id}."
    else
      message = "All the items are picked up successfully."
    end
    render json: { message: message }
  end

  private
    
    def set_put_request
      @put_request = PutRequest.find_by(id: params[:id])
    end
    
    def validate_sub_location(inventory, sub_location)
      @inventories = Inventory.where(id: inventory.id)
      @inventories = @inventories.where("details ->> 'category_l2' IN (?)", sub_location.category) unless sub_location.category.blank?
      @inventories = @inventories.where("details ->> 'brand' IN (?)", sub_location.brand) unless sub_location.brand.blank?
      @inventories = @inventories.where(grade: sub_location.grade) unless sub_location.grade.blank?
      @inventories = @inventories.where(disposition: sub_location.disposition) unless sub_location.disposition.blank?
      
      raise CustomErrors.new "Invalid Sub Location!" unless @inventories.present?
    end
    
end