class Api::V1::Warehouse::PendingDispositionSerializer < ActiveModel::Serializer
  attributes :id, :distribution_center_id, :client_id, :tag_number, :return_reason, :details, :gate_pass_id, :sku_code, :item_description, :client_tag_number, :disposition, :grade, :serial_number, :item_price, :brand, :serial_number_2, :rpa_reason, :alert_level, :ageing, :is_active, :status

  def brand
    object.details['brand'] rescue 'NA'
  end

  def disposition
    object.inventory.disposition
  end

  def rpa_reason
    object.inventory.return_reason
  end

  def alert_level
    object.details['criticality']
  end

  def ageing
    "#{(Date.today.to_date - (object.inventory.details["grn_received_time"].to_date)).to_i} d" rescue "0 d"
  end

end