class Api::V2::Warehouse::Oms::Forward::PurchaseOrderReceiptChallansSerializer < ActiveModel::Serializer
  include Utils::Formatting

  attributes :id, :rc_date, :rc_number, :tag_number, :sku_code, :item_description, :serial_number, :quantity, :total_price, :status

  def rc_date
    object.rc_date.to_date.to_s(:p_date1)
  end
end
