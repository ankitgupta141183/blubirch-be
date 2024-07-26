class Api::V2::Warehouse::Oms::Forward::PurchaseOrderItemsSerializer < ActiveModel::Serializer
  attributes :id, :reference_document_no, :tag_number, :sku_code, :item_description, :serial_number, :quantity, :total_price, :status
end
