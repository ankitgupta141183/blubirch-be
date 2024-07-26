class AddNewColumnsToVendorReturns < ActiveRecord::Migration[6.0]
  def change
    add_column :vendor_returns, :vendor_return_order_id, :integer
    add_column :vendor_returns, :order_number, :string
    remove_column :vendor_returns, :claim_id, :integer
    remove_column :vendor_returns, :claim_action_id, :integer 
  end
end
