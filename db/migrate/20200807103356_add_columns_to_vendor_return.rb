class AddColumnsToVendorReturn < ActiveRecord::Migration[6.0]
  def change
    add_column :vendor_returns, :client_sku_master_id, :integer
    add_column :vendor_returns, :sku_code, :string
    add_column :vendor_returns, :item_description, :string
    add_column :vendor_returns, :grade, :string
    add_column :vendor_returns, :vendor, :string
    add_column :vendor_returns, :call_log_id, :string
    add_column :vendor_returns, :status, :string
    add_column :vendor_returns, :brand_inspection_date, :datetime
    add_column :vendor_returns, :brand_inspection_remarks, :text
    add_column :vendor_returns, :settlement_date, :datetime
    add_column :vendor_returns, :settlement_amount, :float
    add_column :vendor_returns, :item_price, :float
    add_column :rtv_attachments, :attachment_file_type, :string

  end
end
