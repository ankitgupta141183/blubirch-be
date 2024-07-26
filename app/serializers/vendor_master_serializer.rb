class VendorMasterSerializer < ActiveModel::Serializer
  attributes :id, :vendor_code, :vendor_email, :vendor_name, :distribution_centers, :vendor_type, :vendor_distributions, :is_contracted_vendor

  def vendor_type
    object.vendor_types.pluck(:vendor_type).join("/")
  end

  def is_contracted_vendor
    object.vendor_types.where(vendor_type_id: LookupValue.find_by(code: "vendor_type_contracted_liquidation").id).any?
  end

  def distribution_centers
    object.distribution_centers.map {|i| {id: i.id, name: i.name, code: i.code}}
  end

  def vendor_distributions
    object.vendor_distributions.map{|t| {id: t.id, distribution_center_id: t.distribution_center_id, vendor_master_id: t.vendor_master_id}}
  end
end