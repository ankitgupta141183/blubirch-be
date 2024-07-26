class Api::V1::Warehouse::EWasteOrderSerializer < ActiveModel::Serializer
  attributes :id, :order_number, :vendor_code, :order_amount, :created_at, :updated_at,
    :lot_name, :lot_desc, :mrp, :end_date, :status, :status_id, :winner_code,:winner_amount, 
    :payment_status, :payment_status_id,:amount_received,:dispatch_ready,:quantity, :lot_ageing,:start_date, :alert_level

  def lot_ageing
    orh = object.e_waste_order_histories.where(status_id: LookupValue.find_by(original_code: "Pending Closure").try(:id)).last
    orh1 = object.e_waste_order_histories.last
    return '' unless orh.present?
    lot_created_date = orh.details["Pending_Closure_created_date"].present? ? TimeDifference.between(orh.details["Pending_Closure_created_date"],Time.now.to_s).in_days.ceil : 0
    if object.status == "Pending Closure"
      status_initiation_date = lot_created_date
    end
    if object.status == "Partial Payment"
      status_initiation_date = orh1.details["Partial_Payment_created_date"].present? ? TimeDifference.between(orh1.details["Partial_Payment_created_date"],Time.now.to_s).in_days.ceil : 0
    end
    if object.status == "Full Payment Received"
      status_initiation_date = orh1.details["Full_Payment_Received_created_date"].present? ? TimeDifference.between(orh1.details["Full_Payment_Received_created_date"],Time.now.to_s).in_days.ceil : 0
    end
    if object.status == "Dispatch Ready"
      status_initiation_date = orh1.details["Dispatch_Ready_created_date"].present? ? TimeDifference.between(orh1.details["Dispatch_Ready_created_date"],Time.now.to_s).in_days.ceil : 0
    end  
    # inward_date = TimeDifference.between(object.inventory.created_at,Time.now.to_s).in_days.ceil || 0
    return status_initiation_date.to_s+'d ' + ' ' + "(" + lot_created_date.to_s + "d" + ")" rescue ''    
  end

  def alert_level
    e_waste = EWaste.where(e_waste_order_id: object.id).last
    return e_waste.details['criticality'] rescue ""
  end

  def dispatch_ready
    dispatch_ready = object.dispatch_ready rescue false     
    if dispatch_ready
     "Yes"
    else
     "No"
    end
  end
  

end
