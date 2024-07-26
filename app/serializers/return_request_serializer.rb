class ReturnRequestSerializer < ActiveModel::Serializer

  attributes :id, :request_number, :invoice_number, :inventories, :details, :deleted_at, :created_at, :updated_at, :city, :aging, :destination_station

  belongs_to :distribution_center
  belongs_to :client
  belongs_to :customer_return_reason  
  belongs_to :return_status

  def invoice_number
  	object.try(:invoice).try(:invoice_number)
  end

  def inventories
  	Inventory.where("details ->> 'return_request_number' = ?", object.try(:request_number))
  end

  def city
    object.try(:distribution_center).try(:city).try(:original_code)
  end

  def destination_station
    object.client.address
  end
  
  def aging
    object.details["approval_sent_date"].present? ? TimeDifference.between(object.details["approval_sent_date"] , Time.now.to_s).in_days.ceil : 0
  end

end
