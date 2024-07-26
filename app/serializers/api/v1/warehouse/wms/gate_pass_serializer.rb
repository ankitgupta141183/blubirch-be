class Api::V1::Warehouse::Wms::GatePassSerializer < ActiveModel::Serializer

  attributes :id, :client_gatepass_number, :source_code, :source_city, :destination_code, :destination_city,
             :sr_number, :dispatch_date, :created_at, :updated_at, :source_address, :source_city, :source_state, 
             :source_country, :source_pincode, :destination_pincode, :destination_address, 
             :destination_state, :details, :status, :is_forward, :document_type, :vendor_code, :vendor_name,
             :batch_number, :synced_response, :synced_response_received_at, :idoc_number, :idoc_created_at,
             :is_error_response_received, :is_error, :assigned_username, :assigned_at, :assigned_status,
             :is_scanned, :assigned_user_id, :status,  :ageing, :total_quantity, :gp_status, :pending_quantity, :inwarded_quanity,
             :document_submitted_time,:total_items

  has_many :gate_pass_inventories

  def assigned_username
    object.try(:assigned_user).try(:username)
  end

  def is_scanned
    gate_pass_status_completed = LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_completed).first
    gate_pass_status_closed = LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_closed).first
    ([gate_pass_status_completed.try(:id), gate_pass_status_closed.try(:id)].include?(object.status_id) ? "Yes" : "No")
  end

  def ageing
    "#{(Date.today.to_date - (object.dispatch_date.to_date)).to_i} d" rescue "0 d"
  end
  
  def inwarded_quanity
    object.gate_pass_inventories.collect(&:inwarded_quantity).sum
  end

  def pending_quantity
    (object.gate_pass_inventories.collect(&:quantity).sum - object.gate_pass_inventories.collect(&:inwarded_quantity).sum rescue 'N/A')
  end

  def gp_status
    total = object.gate_pass_inventories.collect(&:quantity).sum
    inwarded = object.gate_pass_inventories.collect(&:inwarded_quantity).sum
    if total == inwarded
      return 'Closed'
    elsif inwarded == 0
      return 'Open'
    else
      return 'Partial Closed'
    end
  end

  def total_items
    object.gate_pass_inventories.collect(&:quantity).sum
  end

end
