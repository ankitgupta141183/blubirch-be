class TransferInventorySerializer < ActiveModel::Serializer

  attributes :id, :class_name, :main_class_name, :tag_number, :sku_code, :status, :item_description, :location, :sub_location, :category, :created_at, :updated_at

  def main_class_name
    object.class.to_s
  end

  def id
    find_inventory.id
  end

  def class_name
    find_inventory.class.to_s
  end

  def item_description
    find_inventory.item_description
  end
  
  def sku_code
    find_inventory.sku_code
  end

  def location
    find_inventory.distribution_center&.name
  end

  def sub_location
    find_inventory.sub_location&.name
  end

  def category
    find_inventory.client_category&.name
  end

  def find_inventory
    @inventory ||= if object.is_a?Inventory
      object
    elsif object.is_a?ForwardInventory
      object
    else
      object.inventory rescue object.forward_inventory
    end
  end
end
