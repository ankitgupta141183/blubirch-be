class ItemSerializer < ActiveModel::Serializer

  attributes :id, :box_number, :sub_box_number, :location

  def sub_box_number
    object.box_number if object.is_sub_box?
  end

  def box_number
    object.box_number unless object.is_sub_box?
  end
end
