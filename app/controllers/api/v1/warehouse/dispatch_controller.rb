class Api::V1::Warehouse::DispatchController < ApplicationController
  before_action -> { set_pagination_params(params) }, only: [:fetch_orders, :add_items, :dispatch_boxes]

  before_action :get_order_items, :filter_by_tab, :filter_by_params, only: :fetch_orders

  def fetch_orders
    @warehouse_order_items = @warehouse_order_items.page(@current_page).per(@per_page) 
    
    #& Rendering warehouse order items
    render json: @warehouse_order_items, meta: pagination_meta(@warehouse_order_items)
  end

  def create_pick_up_request
    begin
      ActiveRecord::Base.transaction do
        
        #& Step 1
        create_put_request(request_type: :pick_up, pick_up_reason: :packaging)

        #& Step 2
        create_user_requests

        #& Step 3
        create_put_request_items

        render json: { put_request: @put_request, message: "PickUp request successfully created."}, status: :created
      end  
    rescue  Exception => message
      render json: { error: message.to_s }, status: 500
    end
  end

  def create_packaging_request
    begin
      ActiveRecord::Base.transaction do
        
        #& Step 1
        create_put_request(request_type: :packaging, pick_up_reason: nil)

        #& Step 2
        create_user_requests

        #& Step 3
        create_put_request_items

        render json: { put_request: @put_request, message: "Packaging request successfully created."}, status: :created
      end  
    rescue  Exception => message
      render json: { error: message.to_s }, status: 500
    end
  end

  def update_sub_location
    begin
      warehouse_order_items = WarehouseOrderItem.where(id: params[:ids])
      sub_location = SubLocation.find_by(id: params[:sub_location_id])
      raise CustomErrors.new "Invalid ID." if (warehouse_order_items.blank? or sub_location.blank?)
      
      pending_pick_up_status = LookupValue.where(code: "dispatch_status_pending_pick_up").last
      warehouse_order_items.each do |wo_item|
        inventory = wo_item.inventory
        inventory.update(sub_location_id: sub_location.id)
        wo_item.update(tab_status: :pending_pickup, dispatch_request_status: :to_be_created)
        if inventory.status != pending_pick_up_status.original_code
          inventory.update_inventory_status!(pending_pick_up_status, current_user.id)
        end
      end

      render json: {status: :ok}
    rescue  Exception => message
      render json: { error: message.to_s }, status: 500
    end
  end
  
  def add_items
    set_put_request

    distribution_center = @put_request.distribution_center
    
    tab_status = if @put_request.request_type_pick_up?
      "pending_pickup"
    elsif @put_request.request_type_packaging?
      "pending_packaging"
    end
    # Adding some Query for forward inventory and summing up records for active records
    # query = ["inventories.distribution_center_id = ? AND warehouse_order_items.tab_status = #{WarehouseOrderItem.tab_statuses[tab_status]} AND dispatch_request_status = #{WarehouseOrderItem.dispatch_request_statuses["to_be_created"]}", distribution_center.id]
    reverse_query = ["inventories.distribution_center_id = ? AND warehouse_order_items.tab_status = #{WarehouseOrderItem.tab_statuses[tab_status]} AND dispatch_request_status = #{WarehouseOrderItem.dispatch_request_statuses["to_be_created"]}", distribution_center.id]
    forward_query = ["forward_inventories.distribution_center_id = ? AND warehouse_order_items.tab_status = #{WarehouseOrderItem.tab_statuses[tab_status]} AND dispatch_request_status = #{WarehouseOrderItem.dispatch_request_statuses["to_be_created"]}", distribution_center.id]
    #& Getting warehouse order items based on the query
    # @warehouse_order_items = WarehouseOrderItem.joins(:inventory).includes(inventory: [:distribution_center, :sub_location], warehouse_order: :orderable).where(query)

    # Showing the items which only has sub location
    # @warehouse_order_items = @warehouse_order_items.joins(inventory: :sub_location) if @put_request.request_type_pick_up?
    
    @warehouse_order_items = fetch_forward_reverse_warehouse_order_items(reverse_query, forward_query, @put_request.request_type_pick_up?)
    @warehouse_order_items = @warehouse_order_items.where(tag_number: params[:search].to_s.gsub(" ", "").split(',')) if params[:search].present?
    @warehouse_order_items = @warehouse_order_items.order('updated_at desc').page(@current_page).per(@per_page)

    render json: @warehouse_order_items, meta: pagination_meta(@warehouse_order_items)
  end
  
  def write_off
    warehouse_order_item = WarehouseOrderItem.find_by(id: params[:id])
    raise CustomErrors.new "Invalid ID!" if warehouse_order_item.blank?
    raise CustomErrors.new "Please enter the details!" if (params[:raised_against].blank? || params[:debit_amount].blank?)
    
    not_found_items = RequestItem.status_not_found.where(warehouse_order_item_id: warehouse_order_item.id)
    raise CustomErrors.new "Not found items are not present." if not_found_items.blank?
    
    not_found_items.each do |item|
      item.update(status: "wrote_off", raised_against: params[:raised_against], debit_amount: params[:debit_amount])
    end
    warehouse_order_item.update(item_status: :closed)
    inventory = warehouse_order_item.inventory
    inventory.outward_inventory!(@current_user)
    
    render json: {status: :ok}
  end

  def set_disposition
    begin
      ActiveRecord::Base.transaction do
        warehouse_order_items = WarehouseOrderItem.includes(:inventory).where(id: params[:ids], tab_status: "pending_disposition", item_status: :open)
        raise CustomErrors.new "Invalid ID." if warehouse_order_items.blank?
        warehouse_order_items_count = warehouse_order_items.count

        disposition = params[:disposition]
        raise CustomErrors.new "Disposition can not be blank!" if disposition.blank?
        
        warehouse_order_items.each do |warehouse_order_item|
          warehouse_order_item.set_disposition(disposition, current_user)
        end
        render json: { message: "#{warehouse_order_items_count} item(s) moved to #{disposition} successfully." }
      end
    rescue Exception => message
      render json: { error: message.to_s }, status: 500
      return
    end
  end
  
  def dispatch_boxes
    @dispatch_boxes = DispatchBox.includes(:warehouse_order_items).status_pending.order(id: :desc)
    filter_dispatch_boxes
    @dispatch_boxes = @dispatch_boxes.page(@current_page).per(@per_page)
    data = @dispatch_boxes.as_json(only: [:id, :box_number, :orrd, :destination_type, :destination], methods: [:or_document])
    
    render json: {dispatch_boxes: data, meta: pagination_meta(@dispatch_boxes)}
  end
  
  def get_filters_data
    outward_ref_documents = DispatchBox::OUTWARD_REF_DOCUMENTS.map{|i| {id: i[0], name: i[1]} }
    modes = DispatchBox.modes.map{|i| {id: i[1], name: i[0].titleize} }
    logistic_partners = DispatchBox.logistic_partners.map{|i| {id: i[1], name: i[0].titleize} }
    reject_reasons = WarehouseOrderItem.reject_reasons.map{|i| {id: i[1], name: i[0].titleize} }
    request_statuses = WarehouseOrderItem.dispatch_request_statuses.map{|i| {id: i[1], name: i[0].titleize} }
    
    render json: {outward_ref_documents: outward_ref_documents, modes: modes, logistic_partners: logistic_partners, reject_reasons: reject_reasons, request_statuses: request_statuses}
  end
  
  def update_dispatch_details
    ActiveRecord::Base.transaction do
      dispatch_boxes = DispatchBox.where("id in (#{params[:ids].to_s})")
      raise CustomErrors.new "Invalid ID!" unless dispatch_boxes.present?
      
      params[:outward_reference_value] = params[:outward_reference_value].to_s.split(',')
      params[:cancelled_items] = JSON.parse(params[:cancelled_items]) if params[:cancelled_items].present?
      
      dispatch_boxes.validate_dispatch_details(params)
      
      dispatch_boxes.each do |dispatch_box|
        dispatch_box.update_dispatch_details(params)
      end
      
      render json: {message: "Dispatch details updated successfully"}
    end
  end
  
  def get_dispositions
    lookup_key = LookupKey.find_by_code('WAREHOUSE_DISPOSITION')
    dispositions = lookup_key.lookup_values.where(original_code: ["Repair", "Markdown", "Liquidation", "Brand Call-Log"]).pluck(:original_code).map{|code| {id: code, code: code} }
    render json: { dispositions: dispositions }
  end
  
  private
  
  def fetch_forward_reverse_warehouse_order_items(reverse_query, forward_query, request_type_pick_up = false)
    reverse_warehouse_order_items = WarehouseOrderItem.joins(:inventory).where(reverse_query)
    forward_warehouse_order_items = WarehouseOrderItem.joins(:forward_inventory).where(forward_query)

    reverse_warehouse_order_items = reverse_warehouse_order_items.joins(inventory: :sub_location) if request_type_pick_up
    forward_warehouse_order_items = forward_warehouse_order_items.joins(forward_inventory: :sub_location) if request_type_pick_up

    reverse_warehouse_order_items.union(forward_warehouse_order_items).includes(inventory: [:distribution_center, :sub_location], forward_inventory: [:distribution_center, :sub_location], warehouse_order: :orderable)
  end

  def set_put_request
    @put_request = PutRequest.dispatch_requests.find_by(id: params[:id])
  end

  #^ --------- Put request Creation flow -----------
  def create_put_request(request_type:, pick_up_reason:)
    @put_request = PutRequest.new(
      distribution_center_id: params[:put_request][:distribution_center_id], 
      request_type: request_type, 
      pick_up_reason: pick_up_reason, 
      disposition: "Dispatch",
      status: "pending",
      is_dispatch_item: true
    )
    @put_request.save!
  end

  def create_user_requests
    @put_request.assign_users(params[:put_request][:assignee_ids])
  end

  def create_put_request_items
    @put_request.update_request_items(warehouse_order_item_ids: params[:put_request][:inventory_ids], from_dispatch: true)
  end

  def get_order_items
    #& Getting location data
    distribution_centers_ids = @distribution_center.present? ? [@distribution_center.id] : @current_user.distribution_centers.pluck(:id)

    #& Filters
    # Moving the conditions to warehouse_order_items for both reverse and firward inventory fetching
    # query = ["inventories.distribution_center_id IN (?) AND item_status = 1", distribution_centers_ids]
    reverse_query = ["inventories.distribution_center_id IN (?) AND item_status = 1", distribution_centers_ids]
    forward_query = ["forward_inventories.distribution_center_id IN (?) AND item_status = 1", distribution_centers_ids]

    # adding conditions for forward and reverse warehouse_order_items
    reverse_warehouse_order_items = WarehouseOrderItem.joins(:warehouse_order, :inventory).where(reverse_query)
    forward_warehouse_order_items = WarehouseOrderItem.joins(:warehouse_order, :forward_inventory).where(forward_query)
    
    #& Getting warehouse order items based on the query
    # @warehouse_order_items = WarehouseOrderItem.joins(:warehouse_order, :inventory).includes(inventory: [:distribution_center, :sub_location], warehouse_order: :orderable).where(query).order('created_at desc')
    @warehouse_order_items = reverse_warehouse_order_items.union(forward_warehouse_order_items).includes(forward_inventory: [:distribution_center, :sub_location], inventory: [:distribution_center, :sub_location], warehouse_order: :orderable).order('created_at desc')
  end

  def filter_by_tab
    tab_status = params[:tab] || "pending_pickup"
    query = "warehouse_order_items.tab_status = #{WarehouseOrderItem.tab_statuses[tab_status]}"
    @warehouse_order_items = @warehouse_order_items.where(query)
  end
  
  def filter_by_params
    @warehouse_order_items = @warehouse_order_items.where(tag_number: params[:search].to_s.gsub(" ", "").split(',')) if params[:search].present?
    if params[:lot_name].present?
      lot_ids = LiquidationOrder.where('lot_name ILIKE ?', "%#{params[:lot_name]}%").pluck(:id)
      orderable_type = "LiquidationOrder"
      if lot_ids.blank?
        lot_ids = RedeployOrder.where('lot_name ILIKE ?', "%#{params[:lot_name]}%").pluck(:id)
        orderable_type = "RedeployOrder"
      end
      if lot_ids.blank?
        lot_ids = VendorReturnOrder.where('lot_name ILIKE ?', "%#{params[:lot_name]}%").pluck(:id)
        orderable_type = "VendorReturnOrder"
      end
      warehouse_order_ids = WarehouseOrder.where(orderable_type: orderable_type, orderable_id: lot_ids).pluck(:id)
      
      if warehouse_order_ids.blank?
        vendor_codes = VendorMaster.where("vendor_code ILIKE ? OR vendor_name ILIKE ?", "%#{params[:lot_name]}%", "%#{params[:lot_name]}%").pluck(:vendor_code)
        warehouse_order_ids = WarehouseOrder.where(vendor_code: vendor_codes).pluck(:id) if vendor_codes.present?
      end
      
      @warehouse_order_items = @warehouse_order_items.where(warehouse_order_id: warehouse_order_ids.uniq)
    end
    @warehouse_order_items = @warehouse_order_items.where(orrd: params[:outward_reason_ref_order]) if params[:outward_reason_ref_order].present?
    @warehouse_order_items = @warehouse_order_items.where("lower(warehouse_order_items.destination_type) = ?", params[:destination_type].downcase) if params[:destination_type].present?
    @warehouse_order_items = @warehouse_order_items.where("dispatch_request_status = #{params[:request_status]}") if params[:request_status].present?
    # Pending disposition
    @warehouse_order_items = @warehouse_order_items.where(sku_master_code: params[:sku_code]) if params[:sku_code].present?
    @warehouse_order_items = @warehouse_order_items.where("reject_reason = #{params[:reject_reason]}") if params[:reject_reason].present?
    @warehouse_order_items = @warehouse_order_items.where("inventories.details ->> 'category_l3' IN (?)", JSON.parse(params[:category])) if (params[:category].present? and JSON.parse(params[:category]).present?)
  end
  
  def filter_dispatch_boxes
    @dispatch_boxes = @dispatch_boxes.where(box_number: params[:box_number].to_s.gsub(" ", "").split(',')) if params[:box_number].present?
    @dispatch_boxes = @dispatch_boxes.where(orrd: params[:outward_reason_ref_order]) if params[:outward_reason_ref_order].present?
    @dispatch_boxes = @dispatch_boxes.where("lower(destination_type) = ?", params[:destination_type].downcase) if params[:destination_type].present?
    @dispatch_boxes = @dispatch_boxes.where(destination: params[:destination]) if params[:destination].present?
  end
  
end
