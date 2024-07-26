class Api::V1::Warehouse::LiquidationSerializer < ActiveModel::Serializer
  attributes :id, :inventory_id, :tag_number, :client_sku_master_id, :sku_code, 
  :item_description, :sr_number, :location, :brand, :grade, :vendor_code, 
  :distribution_center_id, :details, :liquidation_order_id, :lot_name, :mrp, 
  :map, :status_id, :status, :sales_price ,:item_type , :serial_number, 
  :brand_type, :path, :policy, :serial_no,:select,:item_price, :manual_grade, :request_number, :floor_price, :is_putaway_inwarded

  def select
    return false
  end  
  
  def item_price
    object.inventory.item_price  
  end

  def item_type
    object.client_sku_master.item_type rescue nil
  end

  def brand_type
    type = object.details['own_label'] rescue false     
    if type
     "OL"
    else
     "NON OL"
    end
  end  
  
  def path
    object.details['path'].present? ? object.details['path'] : "NA"
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

  def manual_grade
    (object.status == 'Pending Liquidation Regrade') ? 'Pending Regrade' : object.grade
  end  

  def request_number
    if object.liquidation_request.present?
      object.liquidation_request.request_id.present? ? object.liquidation_request.request_id : ""
    else
      return ""
    end
  end
  
  def is_putaway_inwarded
    object.inventory.putaway_inwarded?
  end

end