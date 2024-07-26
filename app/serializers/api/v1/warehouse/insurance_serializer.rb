class Api::V1::Warehouse::InsuranceSerializer < ActiveModel::Serializer
  include Utils::Formatting
  attributes :id, :inventory_id, :sku_code, :item_description, :tag_number, :grade, :insurance_status, :incident_location, :incident_date, :damage_type, :responsible_vendor, :claim_ticket_number, :claim_amount, :approved_amount, :benchmark_price, :net_recovery, :recovery_percent, :assigned_disposition, :inspection_date, :is_putaway_inwarded

  # TODO: update all these data form PRD
  def incident_date
    format_date(object.created_at.to_date)
    # format_date(object.incident_date)
  end
  
  def incident_location
    "Warehouse"
  end

  def damage_type
    "Handling"
  end

  def inspection_date
    format_date(object.claim_inspection_date.to_date) if object.claim_inspection_date.present?
  end
  
  def approved_amount
    object.approved_amount.to_f.round(2)
  end
  
  def benchmark_price
    object.benchmark_price.to_f.round(2)
  end
  
  def net_recovery
    object.net_recovery.to_f.round(2)
  end
  
  def recovery_percent
    object.recovery_percent.to_f.round(2)
  end
  
  def is_putaway_inwarded
    object.inventory&.putaway_inwarded?
  end

end
