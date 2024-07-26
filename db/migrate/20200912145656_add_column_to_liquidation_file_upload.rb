class AddColumnToLiquidationFileUpload < ActiveRecord::Migration[6.0]
  def change
    add_column :liquidation_file_uploads, :deleted_at, :datetime
  end
end
