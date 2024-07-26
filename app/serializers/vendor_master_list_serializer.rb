class VendorMasterListSerializer < ActiveModel::Serializer
  attributes :id, :vendor_code, :vendor_name, :vendor_type, :is_contracted_vendor

  def vendor_type
    object.vendor_types.pluck(:vendor_type).join("/")
  end

  def is_contracted_vendor
    object.vendor_types.where(vendor_type_id: LookupValue.find_by(code: "vendor_type_contracted_liquidation").id).any?
  end
end