class Api::V2::Warehouse::OutForRentalSerializer < ActiveModel::Serializer
  
  attributes :id, :tag_id, :article_id, :article_description, :distribution_center, :lessee_name, :notice_period_days, :lease_amount, :security_deposit, :lease_start_date, :lease_end_date, :emai_details, :lease_payment_frequency, :rental_reserve_id
  
  def tag_id
    object.tag_number || 'NA'
  end

  def article_id
    object.article_sku || "NA"
  end

  def distribution_center
    object.distribution_center.code
  end

  def lessee_name
    object.buyer_name
  end

  def emai_details
    current_emi = object.current_emi
    is_paid = current_emi&.received_date.present?
    {
      id: current_emi&.id,
      amount: current_emi&.received_rental,
      status: current_emi.blank? || is_paid ? 'To be Dispatched' : 'At Lesse',
      is_paid: current_emi.blank? || is_paid
    }
  end

end