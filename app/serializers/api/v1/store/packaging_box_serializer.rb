class Api::V1::Store::PackagingBoxSerializer < ActiveModel::Serializer
  
  attributes :id, :box_number, :item_count, :user_id, :distribution_center_id

  def item_count
    object.packed_inventories.size
  end

end