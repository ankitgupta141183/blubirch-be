class AddDistributionCentersToMasterFileUploads < ActiveRecord::Migration[6.0]
  def change
    add_column :master_file_uploads, :distribution_center_id, :integer
  end
end
