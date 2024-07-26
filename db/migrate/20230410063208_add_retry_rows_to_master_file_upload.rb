class AddRetryRowsToMasterFileUpload < ActiveRecord::Migration[6.0]
  def change
    add_column :master_file_uploads, :retry_rows, :integer, array: true, default: []
  end
end
