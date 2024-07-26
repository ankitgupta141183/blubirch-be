class Api::V1::Warehouse::LiquidationOrderSerializer < ActiveModel::Serializer
  attributes :id, :order_number, :vendor_code, :order_amount, :created_at, :updated_at,
   :lot_name, :lot_desc, :mrp, :end_date, :status, :status_id, :winner_code,:winner_amount, 
   :payment_status, :payment_status_id,:amount_received,:dispatch_ready,:quantity, 
   :start_date, :floor_price, :reserve_price, :email_sent, :bid_count, :alert_level, :lot_image_urls, :lot_type,
   :buy_now_price, :increment_slab, :created_date, :is_expired, :warehouse_order_status, :remarks, :bill_to, :inventory_deleted, :winner_amount_reason, :selected_vendors, :republish_status, :so_number

  # def lot_ageing
  #   orh = object.liquidation_order_histories.where(status_id: LookupValue.find_by(original_code: "Pending Closure").try(:id)).last
  #   orh1 = object.liquidation_order_histories.last
  #   return '' unless orh.present?
  #   lot_created_date = orh.details["Pending_Closure_created_date"].present? ? TimeDifference.between(orh.details["Pending_Closure_created_date"],Time.now.to_s).in_days.ceil : 0
  #   if object.status == "Pending Closure"
  #     status_initiation_date = lot_created_date
  #   end
  #   if object.status == "Partial Payment"
  #     status_initiation_date = orh1.details["Partial_Payment_created_date"].present? ? TimeDifference.between(orh1.details["Partial_Payment_created_date"],Time.now.to_s).in_days.ceil : 0
  #   end
  #   if object.status == "Full Payment Received"
  #     status_initiation_date = orh1.details["Full_Payment_Received_created_date"].present? ? TimeDifference.between(orh1.details["Full_Payment_Received_created_date"],Time.now.to_s).in_days.ceil : 0
  #   end
  #   if object.status == "Dispatch Ready"
  #     status_initiation_date = orh1.details["Dispatch_Ready_created_date"].present? ? TimeDifference.between(orh1.details["Dispatch_Ready_created_date"],Time.now.to_s).in_days.ceil : 0
  #   end  
  #   # inward_date = TimeDifference.between(object.inventory.created_at,Time.now.to_s).in_days.ceil || 0
  #   return status_initiation_date.to_s+'d ' + ' ' + "(" + lot_created_date.to_s + "d" + ")" rescue ''
  
     
  # end

  def dispatch_ready
    dispatch_ready = object.dispatch_ready rescue false     
    if dispatch_ready
     "Yes"
    else
     "No"
    end
  end
  
  # def alert_level
  #   object.details['criticality'] rescue "" 
  # end

  def start_date
    object.start_date_with_localtime.strftime('%d/%m/%Y %H:%M %p') rescue ""
  end

  def end_date
    object.end_date_with_localtime.strftime('%d/%m/%Y %H:%M %p') rescue ""
  end

  def email_sent
    object.details['email_sent'].present?
  end

  def bid_count
    object.quotations.size
  end

  def alert_level
    'Low'
  end

  def created_date
    object.created_at.strftime('%d/%m/%Y')
  end

  def warehouse_order_status
    if object.warehouse_orders.present?
      status = LookupValue.find(object.warehouse_orders.last.status_id)
      status.original_code
    else
      "N/A"
    end
  end

  def is_expired
    object.is_expired?
  end

  def bill_to
    (object.details["billing_to_id"].present? ? object.details["billing_to_id"] : '') rescue ""
  end

  def inventory_deleted
    object.details['items_deleted'].present?
  end

  def winner_amount_reason
    object.details['winner_amount_update_reason'] rescue ''
  end

  def selected_vendors
    object.details["vendor_lists"] rescue []
  end

  def so_number
    object.details["so_number"] rescue ""
  end
end
