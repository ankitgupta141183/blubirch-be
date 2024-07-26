class Api::V2::Warehouse::Oms::Reverse::ReplacementOrderItemsSerializer < ActiveModel::Serializer
  attributes :id, :invoice_no, :reference_document_no, :tag_number, :sku_code, :item_description, :serial_number, :quantity, :total_price, :status
end
