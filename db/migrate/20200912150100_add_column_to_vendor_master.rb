class AddColumnToVendorMaster < ActiveRecord::Migration[6.0]
  def change
    add_column :vendor_masters, :deleted_at, :datetime
  end
end
