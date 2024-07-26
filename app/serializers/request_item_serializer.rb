class RequestItemSerializer < ActiveModel::Serializer

  attributes :id, :sequence, :inventory_id, :warehouse_order_item_id, :tag_number, :sku_code, :item_description, :grade, :serial_number, :category, :sub_location_id, :sub_location, :brand, :status, :created_at
  

  def tag_number
    object.inventory.tag_number
  end
  
  def sku_code
    object.inventory.sku_code
  end
  
  def item_description
    object.inventory.item_description
  end
  
  def grade
    object.inventory.grade
  end
  
  def serial_number
    object.inventory.serial_number
  end
  
  def category
    object.inventory.details['category_l3']
  end
  
  def brand
    object.inventory.details['brand']
  end
  
  def sub_location_id
    object.inventory.sub_location_id
  end
  
  def sub_location
    object.inventory.sub_location&.code
  end
  
  def created_at
    object.created_at.strftime("%d/%m/%Y %I:%M %p")
  end
  
  def status
    object.status&.humanize
  end

end
