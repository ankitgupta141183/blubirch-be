class Api::V1::Warehouse::LiquidationOrderVendorSerializer < ActiveModel::Serializer
  attributes :id, :vendor_code, :vendor_email, :vendor_name

  def vendor_code
    object.vendor_master.vendor_code
  end

  def vendor_email
    object.vendor_master.vendor_email
  end

  def vendor_name
    object.vendor_master.vendor_name
  end
end