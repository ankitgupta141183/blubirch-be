class AddVendorTypeIdToVendorMaster < ActiveRecord::Migration[6.0]
  def change
  	add_column :vendor_masters, :vendor_type_id, :integer
  end
end
