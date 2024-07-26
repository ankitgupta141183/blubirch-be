class InvoiceSerializer < ActiveModel::Serializer

  attributes :id, :invoice_number, :details, :available_return_reasons, :return_reasons, :pending_store_return_requests, :invoice_inventory_details, :client, :distribution_center, :deleted_at, :created_at, :updated_at

  belongs_to :distribution_center
  belongs_to :client
  has_many :invoice_inventory_details  

  def available_return_reasons
  	approval_sent_return_reasons = object.return_requests.includes(:customer_return_reason).where("status_id != ?", LookupValue.where(code: Rails.application.credentials.return_request_pending_store_approval).first.try(:id)).references(:customer_return_reason).collect(&:customer_return_reason).uniq
  	approval_sent_return_reasons.present? ? (CustomerReturnReason.all - approval_sent_return_reasons) : CustomerReturnReason.all  	
  end

  def return_reasons
    CustomerReturnReason.all
  end

  def pending_store_return_requests
  	object.return_requests.where("status_id = ?", LookupValue.where(code: Rails.application.credentials.return_request_pending_store_approval).first.try(:id))
  end

  

end
