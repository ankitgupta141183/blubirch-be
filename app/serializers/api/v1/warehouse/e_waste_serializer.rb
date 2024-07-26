class Api::V1::Warehouse::EWasteSerializer < ActiveModel::Serializer
  attributes :id, :inventory_id, :tag_number, :client_sku_master_id, :sku_code, 
  :item_description, :sr_number, :location, :brand, :grade, :vendor_code, 
  :distribution_center_id, :details, :e_waste_order_id, 
  :lot_name, :mrp, :map, :status_id, :status, 
  :sales_price ,:item_type, :serial_number, 
  :serial_number_2, :dispatch_ageing,
  :brand_type, :policy, :serial_no, :alert_level


  def item_type
    object.client_sku_master.item_type rescue nil
    # ClientSkuMaster.find_by_code(object.sku_code).item_type  rescue nil
  end

  def alert_level
    object.details['criticality']
  end

  def dispatch_ageing
    orh = object.e_waste_histories.where(status_id: LookupValue.find_by(code: Rails.application.credentials.e_waste_status_pending_e_waste_dispatch).try(:id)).first
    return '' unless orh.present?
    dispatch_date = orh.details["pending_e_waste_dispatch_created_at"].present? ? (Date.today.to_date - orh.details["pending_e_waste_dispatch_created_at"].to_date).to_i : 0 rescue nil
    inward_date = (Date.today.to_date - object.inventory.details["grn_received_time"].to_date).to_i || 0 rescue nil
    return dispatch_date.to_s+'d ' + ' ' + "(" + inward_date.to_s + "d" + ")" rescue ''
  end

  def brand_type
    type = object.details['own_label'] rescue false     
    if type
     "OL"
    else
     "NON OL"
    end
  end  
    
  def policy
    object.details['policy_type']  rescue nil
  end


  def serial_no
    if object.serial_number  && object.serial_number_2
      return object.serial_number , object.serial_number_2
    elsif   !object.serial_number_2  && object.serial_number
      return object.serial_number
    elsif   !object.serial_number  && object.serial_number
      return  object.serial_number_2
    end    
  end  
  
end