class PutAwaySerializer < ActiveModel::Serializer

  attributes :id, :distribution_center_id, :distribution_center, :tag_number, :sku_code, :item_description, :grade, :serial_number, :category, :sub_location_id, :sub_location, :brand, :disposition, :inward_date, :obd_number, :rdd_number


  def category
    object.details['category_l3']
  end
  
  def brand
    object.details['brand']
  end
  
  def sub_location
    object.sub_location&.code
  end
  
  def distribution_center
    object.distribution_center&.code
  end
  
  def inward_date
    object.created_at.strftime("%d/%m/%Y")
  end
  
  def obd_number
    object.gate_pass&.client_gatepass_number
  end
  
  def rdd_number
    object.details['rdd_number']
  end

end
