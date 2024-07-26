class AddLiquidationLotFileUploadAccountSetting < ActiveRecord::Migration[6.0]
  def change
    add_column :account_settings, :liquidation_lot_file_upload, :boolean, default: false
    add_column :account_settings, :liquidation_client_category_file_path, :string
    add_column :account_settings, :organization_name, :string
    add_column :account_settings, :service_request_id, :string
  end
end
