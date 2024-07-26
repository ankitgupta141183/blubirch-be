class AddColumnInwardTypeToInventoryFileUpload < ActiveRecord::Migration[6.0]
  def change
    add_column :inventory_file_uploads, :inward_type, :string
  end
end
