class AddUniqueIndexToGatePassInventories < ActiveRecord::Migration[6.0]
  def change
    add_index(:gate_pass_inventories, [:gate_pass_id, :item_number, :sku_code, :quantity, :pickslip_number], :unique => true, :name => 'by_item_quantity_sku_gate_pass_pickslip_number')
  end
end
