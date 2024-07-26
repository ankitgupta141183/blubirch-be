class OutboundItemListSerializer < ActiveModel::Serializer

  attributes :item_number, :sku_code, :sku_description, :category_code, :ean, :serial_number, :imei1, :imei2,
  					 :quantity, :outwarded_quantity, :scan_id, :destination_code, :source_code,
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
    (object.try(:outbound_document).present? ? (object.try(:outbound_document).try(:document_submitted_time).localtime("+05:30").strftime("%d/%m/%Y %H:%M:%S") rescue nil) : nil)
  end

  def pushed_at
    (object.try(:pushed_at).present? ? (object.try(:pushed_at).localtime("+05:30").strftime("%d/%m/%Y %H:%M:%S") rescue nil) : nil)
  end

  def quantity
  	object.quantity
  end

  def outwarded_quantity
  	object.try(:outwarded_quantity).present? ? object.outwarded_quantity : object.quantity
  end

  def scan_id
  	object.try(:scan_id).present? ? object.scan_id : object.try(:outbound_document_article).try(:scan_id)
  end

  def destination_code
  	object.outbound_document.destination_code
  end

  def source_code
  	object.outbound_document.source_code
  end

  def short_quantity
    object.short_quantity
  end

  def short_reason
    object.try(:short_reason).present? ? object.try(:short_reason) : nil
  end

end
