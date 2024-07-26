class AddColumnToVendorReturn < ActiveRecord::Migration[6.0]
  def change
    add_column :vendor_returns, :settlement_remark, :text
    add_column :vendor_returns, :action_remark, :text
  end
end
