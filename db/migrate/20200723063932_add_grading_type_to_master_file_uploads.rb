class AddGradingTypeToMasterFileUploads < ActiveRecord::Migration[6.0]
  def change
  	add_column :master_file_uploads, :grading_type, :string
  end
end
