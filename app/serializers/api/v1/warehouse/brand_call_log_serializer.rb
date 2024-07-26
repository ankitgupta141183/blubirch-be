class Api::V1::Warehouse::BrandCallLogSerializer < ActiveModel::Serializer
  include Utils::Formatting

  attributes :id, :inventory_id, :sku_code, :item_description, :tag_number, :grade, :brand, :status, :supplier, :ticket_number, :ticket_date, :item_price, :purchase_price, :benchmark_price, :net_recovery, :recovery_percent, :assigned_disposition, :inspection_date, :is_putaway_inwarded


  def ticket_date
    format_date(object.ticket_date)
  end
  
  def inspection_date
    format_date(object.inspection_date)
  end

  def benchmark_price
    object.details["purchase_price"].to_f
  end
  
  def net_recovery
    object.net_recovery.to_f.round(2)
  end
  
  def recovery_percent
    object.recovery_percent.to_f.round(2)
  end
  
  def purchase_price
    object.details["purchase_price"].to_f
  end
  
  def is_putaway_inwarded
    object.inventory&.putaway_inwarded?
  end

end
