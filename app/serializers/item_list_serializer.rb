class ItemListSerializer < ActiveModel::Serializer

  attributes :item_number, :sku_code, :sku_description, :category_code, :ean, :serial_number, :imei1, :imei2,
  					 :quantity, :inwarded_quantity, :scan_id, :pickslip_number, :destination_code, :source_code,
             :short_quantity, :short_reason, :scanned_time, :synced_time, :document_submitted_time, :pushed_at
  
  def item_number
  	(object.try(:item_number).present? ? object.item_number : object.details["item_number"])
  end

  def sku_code
  	object.sku_code
  end

  def sku_description
  	object.item_description
  end

  def category_code
  	(object.try(:merchandise_category).present? ? object.merchandise_category : object.details["category_code_l3"])
  end

  def ean
  	(object.try(:ean).present? ? object.ean : object.details["ean"])
  end

  def serial_number
  	(object.try(:serial_number).present? ? object.serial_number : nil)
  end

  def imei1
  	(object.try(:imei1).present? ? object.imei1 : nil)
  end

  def imei2
  	(object.try(:imei2).present? ? object.imei2 : nil)
  end

  def scanned_time
    (object.try(:scanned_time).present? ? object.scanned_time : nil)
  end

  def synced_time
    (object.try(:synced_time).present? ? object.synced_time : nil)
  end

  def document_submitted_time
    (object.try(:gate_pass).present? ? (object.try(:gate_pass).try(:document_submitted_time).localtime("+05:30").strftime("%d/%m/%Y %H:%M:%S") rescue nil) : nil)
  end

  def pushed_at
    (object.try(:pushed_at).present? ? (object.try(:pushed_at).localtime("+05:30").strftime("%d/%m/%Y %H:%M:%S") rescue nil) : nil)
  end

  def quantity
  	object.quantity
  end

  def inwarded_quantity
  	object.try(:inwarded_quantity).present? ? object.inwarded_quantity : object.quantity
  end

  def scan_id
  	object.try(:scan_id).present? ? object.scan_id : object.try(:gate_pass_inventory).try(:scan_id)
  end

  def pickslip_number
  	object.try(:pickslip_number).present? ? object.pickslip_number : object.try(:gate_pass_inventory).try(:pickslip_number)
  end

  def destination_code
  	object.gate_pass.destination_code
  end

  def source_code
  	object.gate_pass.source_code.present? ? object.gate_pass.source_code : object.gate_pass.vendor_code
  end

  def short_quantity
    object.short_quantity
  end

  def short_reason
    object.try(:short_reason).present? ? object.try(:short_reason) : nil
  end

end
