class Api::V1::Warehouse::WarehouseOrderDocumentSerializer < ActiveModel::Serializer
  attributes :site_name, :inventories, :url, :document_name, :reference_number

  def site_name
    name = ''
    case object.class.name
    when "WarehouseOrder"
      name = object.distribution_center.code
    when "WarehouseOrderDocument"
      name = object.attachable.distribution_center.code
    when "InventoryDocument"
      name = object.inventory.distribution_center.code
    end
    return name
  end

  def inventories
    if object.class.name == 'WarehouseOrderDocument'
      inventories = object.attachable.warehouse_order_items.map(& :inventory)
    elsif object.class.name == 'WarehouseOrder'
      inventories = object.warehouse_order_items.map(& :inventory)
    elsif object.class.name == 'InventoryDocument'
      if LookupValue.find(object.document_name_id).original_code == 'OBD'
        inventories = GatePass.find_by(client_gatepass_number: object.reference_number).inventories
      else
        inventories = InventoryDocument.where(reference_number: object.reference_number).map(& :inventory)
      end
    end
    return inventories
  end

  def url
    url = ''
    case object.class.name
    when "WarehouseOrder"
      url = ""
    when "WarehouseOrderDocument"
      url = object.attachment_url
    when "InventoryDocument"
      url = object.attachment_url
    end
    return url
  end

  def document_name
    doc_name = ''
    case object.class.name
    when "WarehouseOrder"
      doc_name = object.delivery_reference_number
    when "WarehouseOrderDocument"
      doc_name = object.document_name
    when "InventoryDocument"
      doc_name = LookupValue.find(object.document_name_id).original_code
    end
    return doc_name
  end

  def reference_number
    number = ''
    case object.class.name
    when "WarehouseOrder"
      number = object.outward_invoice_number
    when "WarehouseOrderDocument"
      number = object.reference_number
    when "InventoryDocument"
      number = object.reference_number
    end
    return number
  end

end