class Api::V2::Warehouse::LiquidationSerializer < ActiveModel::Serializer
  attributes :id, :inventory_id, :tag_number, :bench_mark_price, :grade, :article_description, :category, :article_id, :ewaste, :has_inventory_gate_pass, :destination_city, :is_putaway_inwarded, :vendor_code, :b2c_publish_status, :ecom_liquidation_id, :allow_resync, :platform_response

  def bench_mark_price
    object.bench_mark_price
  end

  def article_description
    object.item_description
  end

  def grade
    (object.status == 'Pending Liquidation Regrade') ? 'Pending Regrade' : object.grade
  end

  def category
    object.client_category.path.pluck(:name).join(' -> ') rescue ''
  end

  def article_id
    object.sku_code
  end

  def ewaste
    object.not_defined? ? '' : object.is_ewaste
  end

  def has_inventory_gate_pass
    object.inventory.gate_pass_inventory_id.present? rescue false
  end
  
  def destination_city
    object.inventory&.distribution_center&.city&.original_code
  end
  
  def is_putaway_inwarded
    object.inventory.putaway_inwarded? rescue false
  end

  def ecom_liquidation_id
    (object.ecom_liquidations.first.id rescue nil)
  end

  def allow_resync
    if object.ecom_liquidations.blank?
      false
    else
      (object.b2c_publish_status_failed? || object.b2c_publish_status_publish_initiated?) && time_difference(object.updated_at, 10)
    end
  end

  def platform_response
    (object.ecom_liquidations.first.platform_response rescue '')
  end
end