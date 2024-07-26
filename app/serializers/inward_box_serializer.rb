class InwardBoxSerializer < ActiveModel::Serializer

  attributes :id, :location, :client_id, :location, :sub_location, :status, :created_at, :updated_at

  def sub_box_number
    object.box_number if object.is_sub_box?
  end

  def box_number
    object.box_number unless object.is_sub_box?
  end
end
