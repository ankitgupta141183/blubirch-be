# frozen_string_literal: true

class ReturnItemSerializer < ActiveModel::Serializer
  include Utils::Formatting

  attributes :id, :return_request_id, :return_sub_request_id, :return_type, :channel, :status_id, :status, :return_reason, :return_sub_reason,
             :return_request_sub_type, :item_location, :sku_code, :quantity, :created_at, :updated_at, :created_date, :return_type_id, :channel_id, :return_reason_id,
             :return_sub_reason_id, :return_request_sub_type_id, :item_location_id, :serial_number, :reference_document, :reference_document_number,
             :sku_description, :details, :return_inventory_information_id, :location_id, :deleted_at, :user_id, :client_id, :item_amount, :tag_number, :irrd_number, :box_number,
             :suggested_pickup_date, :logistic_partner, :pickup_location, :delivery_location

  belongs_to :user

  def created_date
    format_date(object.created_at.to_date)
  end

  delegate :item_amount, to: :object

  def suggested_pickup_date
    format_date(object.suggested_pickup_date)
  end

  delegate :pickup_location, to: :object

  def delivery_location
    object.delivery_location&.code
  end
end
