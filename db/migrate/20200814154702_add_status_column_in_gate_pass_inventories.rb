class AddStatusColumnInGatePassInventories < ActiveRecord::Migration[6.0]
  def change
    add_column :gate_pass_inventories, :status_id, :integer
    add_column :gate_pass_inventories, :status, :string
    add_index :gate_pass_inventories, :status_id
  end
end
