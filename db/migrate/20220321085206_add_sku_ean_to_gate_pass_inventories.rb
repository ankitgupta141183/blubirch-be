class AddSkuEanToGatePassInventories < ActiveRecord::Migration[6.0]
  def change
    add_column :gate_pass_inventories, :sku_eans, :text, array: true, default: []
  end
end
