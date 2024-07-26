class Api::V2::Warehouse::RentalPendingPaymentSerializer < ActiveModel::Serializer
  
  attributes :id, :tag_id, :article_id, :article_description, :distribution_center, :lessee_name, :notice_period_days, :lease_amount, :security_deposit, :lease_start_date, :lease_end_date, :lease_payment_frequency, :rental_reserve_id
  
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
end