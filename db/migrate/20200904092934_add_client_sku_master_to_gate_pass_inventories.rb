class AddClientSkuMasterToGatePassInventories < ActiveRecord::Migration[6.0]
  def change
  	add_column :gate_pass_inventories, :client_sku_master_id, :integer
  	add_column :inventories, :client_category_id, :integer
  	add_column :liquidations, :client_category_id, :integer
  end
end
