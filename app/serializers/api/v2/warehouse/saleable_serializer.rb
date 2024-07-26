class Api::V2::Warehouse::SaleableSerializer < ActiveModel::Serializer
  attributes :id, :tag_number, :article_description, :article_sku, :reserve_number, :selling_price, :payment_received, :reserve_date, :benchmark_date, :payment_status, :vendor_code, :vendor_name, :location
end
