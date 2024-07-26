class AddColumnToGatePassInventory < ActiveRecord::Migration[6.0]
  def change
    add_column :gate_pass_inventories, :scan_id, :string
    add_column :gate_pass_inventories, :item_number, :string
  end
end
