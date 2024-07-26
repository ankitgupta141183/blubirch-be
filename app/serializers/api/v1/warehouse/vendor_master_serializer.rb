class Api::V1::Warehouse::VendorMasterSerializer < ActiveModel::Serializer
  attributes :id, :vendor_code, :vendor_code_name, :vendor_email, :vendor_city, :brand, :vendor_name

  def vendor_code_name
    "#{object.vendor_code} - #{object.vendor_name}"
  end

end
