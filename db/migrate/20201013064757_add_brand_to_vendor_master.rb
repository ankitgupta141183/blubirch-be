class AddBrandToVendorMaster < ActiveRecord::Migration[6.0]
  def change
  	add_column :vendor_masters, :brand, :string
  end
end
