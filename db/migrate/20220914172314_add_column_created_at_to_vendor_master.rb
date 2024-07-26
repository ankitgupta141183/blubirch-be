class AddColumnCreatedAtToVendorMaster < ActiveRecord::Migration[6.0]
  def change
    add_column :vendor_masters, :created_at, :datetime
    add_column :vendor_masters, :updated_at, :datetime
  end
end
