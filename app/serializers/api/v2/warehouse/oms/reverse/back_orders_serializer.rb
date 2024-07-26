class Api::V2::Warehouse::Oms::Reverse::BackOrdersSerializer < ActiveModel::Serializer
attributes :id, :rrd_creation_date, :reason_reference_document_no, :amount, :status, :sender, :receiver, :order_reason, :payment_term_details

  def sender
    object.vendor_details['vendor_name']
  end

  def receiver
    object.receiving_location_details['name']
  end

  def payment_term_details
    object.payment_term_details.map { |key, value|
      value = "#{value}%" if key.include?('per_')
      "#{key.gsub('per_', '').titleize} #{value}"
    }.join(', ')
  end
end
