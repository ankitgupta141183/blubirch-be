class AddVendorMasterToMasterFileUpload < ActiveRecord::Migration[6.0]
  def change
    add_column :master_file_uploads, :vendor_master_id, :integer
  end
end
