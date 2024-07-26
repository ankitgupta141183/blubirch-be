class Api::V1::Warehouse::Wms::OutboundDocumentSerializer < ActiveModel::Serializer

  attributes :id, :client_gatepass_number, :source_code, :source_city, :destination_code, :destination_city,
             :document_date, :created_at, :updated_at, :source_address, :source_city, :source_state, 
             :source_country, :source_pincode, :destination_pincode, :destination_address, 
             :destination_state, :details, :status, :is_forward, :document_type,
             :batch_number, :synced_response, :synced_response_received_at,
             :is_error_response_received, :is_error, :assigned_username, :assigned_at, :assigned_status,
             :is_scanned, :assigned_user_id, :total_quantity, :gp_status, :pending_quantity, :outwarded_quanity,
             :document_submitted_time, :total_items, :vendor_code, :vendor_name

  has_many :outbound_document_articles

  def assigned_username
    object.try(:assigned_user).try(:username)
  end

  def is_scanned
    gate_pass_status_completed = LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_completed).first
    gate_pass_status_closed = LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_closed).first
    ([gate_pass_status_completed.try(:id), gate_pass_status_closed.try(:id)].include?(object.status_id) ? "Yes" : "No")
  end
  
  def outwarded_quanity
    object.outbound_document_articles.collect(&:outwarded_quantity).sum
  end

  def pending_quantity
    (object.outbound_document_articles.collect(&:quantity).sum - object.outbound_document_articles.collect(&:outwarded_quantity).sum rescue 'N/A')
  end

  def gp_status
    total = object.outbound_document_articles.collect(&:quantity).sum
    outwarded = object.outbound_document_articles.collect(&:outwarded_quantity).sum
    if total == outwarded
      return 'Closed'
    elsif outwarded == 0
      return 'Open'
    else
      return 'Partial Closed'
    end
  end

  def total_items
    object.outbound_document_articles.collect(&:quantity).sum
  end

end
