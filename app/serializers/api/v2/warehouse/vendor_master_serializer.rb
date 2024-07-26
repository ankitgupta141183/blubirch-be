class Api::V2::Warehouse::VendorMasterSerializer < ActiveModel::Serializer
  attributes :id, :vendor_code, :vendor_email, :vendor_name, :e_waste_certificate, :vendor_address, :vendor_city, :vendor_phone, :vendor_pin, :vendor_state
end
