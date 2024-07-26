class Api::V2::Warehouse::Oms::Reverse::LeaseOrdersSerializer < ActiveModel::Serializer
  include Utils::Formatting
  attributes :id, :reason_reference_document_no, :creation_date, :sender, :receiver, :billing_location, :status, :payment_terms, :order_reason, :remarks, :terms_and_conditions
  def creation_date
    object.created_at.to_s(:p_long)
  end

  def sender
    object.vendor_details['vendor_name']
  end

  def receiver
    object.receiving_location_details['name']
  end

  def billing_location
    object.billing_location_details['name']
  end

  def payment_terms
    if object.has_payment_terms?
      "In advance (#{object.payment_term_details['per_in_advance']}%), on delivery (#{object.payment_term_details['per_on_delivery']}%), credit(#{object.payment_term_details['per_on_credit']}% in #{object.payment_term_details['no_of_days']} days)"
    else
      'NA'
    end
  end
  
end
