class AddVendorCodeToRepairTable < ActiveRecord::Migration[6.0]
  def change
    add_column :repairs, :vendor_code, :string
  end
end
