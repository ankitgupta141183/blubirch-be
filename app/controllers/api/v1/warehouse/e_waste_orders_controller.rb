class Api::V1::Warehouse::EWasteOrdersController < ApplicationController
  before_action :set_api_v1_warehouse_e_waste_order, only: [:show, :update, :destroy]

  # GET /api/v1/warehouse/e_waste_orders
  def index
    set_pagination_params(params)
    @ewaste_orders = EWasteOrder.all.page(@current_page).per(@per_page)
    render json: @ewaste_orders, meta: pagination_meta(@ewaste_orders)
  end


  def create_lot    

    lot_status = LookupValue.find_by(code:Rails.application.credentials.lot_status_pending_closure)
    new_e_waste_status = LookupValue.find_by(code:Rails.application.credentials.e_waste_status_pending_e_waste_dispatch)

    e_waste_order = EWasteOrder.create(order_number: "OR-EWaste-#{SecureRandom.hex(6)}" , 
     lot_name: params[:lot_name], lot_desc: params[:lot_desc],
     mrp: params[:lot_mrp], end_date: params[:end_date], 
     start_date: Time.now,
     status:lot_status.original_code, status_id: lot_status.id, 
     order_amount: params[:lot_expected_price], 
     quantity:params[:ewaste_obj].count)  
    ewaste_order_history = EWasteOrderHistory.create(e_waste_order_id:e_waste_order.id, 
      status: lot_status.original_code, status_id: lot_status.id, 
      details: {"Pending_Closure_created_date" => Time.now.to_s } ) 
    
    params[:vendor_code].each do |i|
      vendor_m_id = VendorMaster.find_by_vendor_code(i) rescue nil
      EWasteOrderVendor.create(e_waste_order_id:e_waste_order.id, 
        vendor_master_id:vendor_m_id.id)
    end 

    params[:ewaste_obj].each do |i|
      ewaste_item = EWaste.find(i)
      ewaste_item.update( lot_name: params[:lot_name], 
      e_waste_order_id: e_waste_order.id , status: new_e_waste_status.original_code , 
      status_id: new_e_waste_status.id )
      EWasteHistory.create(
        e_waste_id: ewaste_item.id , 
        status_id: new_e_waste_status.try(:id), 
        status: new_e_waste_status.try(:original_code),
        details: {"status_changed_by_user_id" => current_user.id, "status_changed_by_user_name" => current_user.full_name } )
    end

    render json: "success" 
  end

  def update_lot_status

    params[:id]
    params[:winner_code]
    params[:winner_amount]
    params[:payment_status]
    params[:amount_received]
    params[:dispatch_status]
    params[:lot_status]

    @e_waste_order = EWasteOrder.find(params[:id])
    if params[:lot_status] == "Partial Payment"
      @e_waste_order.status =   LookupValue.find_by(code:Rails.application.credentials.lot_status_partial_payment).original_code
      @e_waste_order.status_id =  LookupValue.find_by(code:Rails.application.credentials.lot_status_partial_payment).id
      e_waste_order_history = EWasteOrderHistory.create(e_waste_order_id:@e_waste_order.id, status: @e_waste_order.status, status_id: @e_waste_order.status_id, details: {"Partial_Payment_created_date" => Time.now.to_s } ) 
    elsif params[:lot_status] == "Full Payment Received"      
      @e_waste_order.status =  LookupValue.find_by(code:Rails.application.credentials.lot_status_full_payment_received).original_code
      @e_waste_order.status_id = LookupValue.find_by(code:Rails.application.credentials.lot_status_full_payment_received).id
      e_waste_order_history = EWasteOrderHistory.create(e_waste_order_id:@e_waste_order.id, status: @e_waste_order.status, status_id: @e_waste_order.status_id, details: {"Full_Payment_Received_created_date" => Time.now.to_s } ) 
    elsif params[:lot_status] == "Dispatch Ready"
      @e_waste_order.status = LookupValue.find_by(code:Rails.application.credentials.lot_status_dispatch_ready).original_code
      @e_waste_order.status_id =  LookupValue.find_by(code:Rails.application.credentials.lot_status_dispatch_ready).id
      e_waste_order_history = EWasteOrderHistory.create(e_waste_order_id:@e_waste_order.id, status: @e_waste_order.status, status_id: @e_waste_order.status_id, details: {"Dispatch_Ready_created_date" => Time.now.to_s } ) 
    end  

    @e_waste_order.winner_code = params[:winner_code]
    @e_waste_order.winner_amount = params[:winner_amount]
    @e_waste_order.payment_status =  params[:payment_status] 
    @e_waste_order.amount_received = params[:amount_received]
    @e_waste_order.dispatch_ready = params[:dispatch_status]

    if @e_waste_order.save
      if params[:dispatch_status] == "true"
          @e_waste_item_list = @e_waste_order.e_wastes
          warehouse_order = @e_waste_order.warehouse_orders.create( 
            orderable:  @e_waste_order, 
            vendor_code: params[:winner_code], 
            total_quantity:  @e_waste_item_list.count, 
            client_id: @e_waste_item_list.last.client_id,
            reference_number: @e_waste_order.order_number,
            distribution_center_id: @e_waste_item_list.first.distribution_center_id, 
            status_id:LookupValue.find_by(code:Rails.application.credentials.order_status_warehouse_pending_pick).id)    
          
          @e_waste_item_list.each do |e_waste_item|
          
             client_sku_master = ClientSkuMaster.find_by_code(e_waste_item.sku_code)  rescue nil
             client_category = client_sku_master.client_category rescue nil
          
              WarehouseOrderItem.create( warehouse_order_id:warehouse_order.id , 
                inventory_id: e_waste_item.inventory_id , 
                client_category_id: client_category.try(:id) , 
                client_category_name: client_category.try(:name) , 
                sku_master_code: client_sku_master.try(:code) , 
                item_description: e_waste_item.item_description , 
                tag_number: e_waste_item.tag_number , 
                serial_number: e_waste_item.inventory.serial_number ,
                quantity: e_waste_item.sales_price , 
                status_id:LookupValue.find_by(code:Rails.application.credentials.order_status_warehouse_pending_pick).id, 
                status: LookupValue.find_by(code:Rails.application.credentials.order_status_warehouse_pending_pick).original_code)
              end
        end
      render json: @e_waste_order
    else
      render json: @e_waste_order.errors, status: :unprocessable_entity
    end

  end
  
  def delete_lot
    @e_waste_item = EWasteOrder.find(params[:id]).e_wastes
    new_e_waste_status = LookupValue.find_by(code:Rails.application.credentials.e_waste_status_pending_e_waste)
    @e_waste_item.each do |item|
      item.update( lot_name: "", e_waste_order_id: "" , status: new_e_waste_status.original_code , status_id: new_e_waste_status.id )
    end 
    EWasteOrder.find(params[:id]).destroy
    render json: "success" 
  end 


  def winner_code_list  
    vendor_master_ids =  EWasteOrderVendor.where(e_waste_order_id: params[:id]).pluck(:vendor_master_id)
    @vendor_code = VendorMaster.find(vendor_master_ids).pluck(:vendor_code)  
    render json: @vendor_code
  end 

 
end
