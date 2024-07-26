# frozen_string_literal: true

class RejectedBoxItemSerializer < ActiveModel::Serializer
  attributes :id, :box_tag_id, :client_id, :reverse_dispatch_document_number, :customer_detail, :current_status, :created_at, :updated_at

  def customer_detail
    object.location
  end

  def box_tag_id
    object.box_status == 'Box Rejected' && object.tag_number.blank? ? object.box_number : object.tag_number
  end
end
