class AddFlowColumnToVendorReturn < ActiveRecord::Migration[6.0]
  def change
    add_column :vendor_returns, :work_flow_name, :string
    add_column :vendor_returns, :blubirch_claim_id, :string
  end
end
