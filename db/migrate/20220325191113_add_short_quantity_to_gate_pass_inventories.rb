class AddShortQuantityToGatePassInventories < ActiveRecord::Migration[6.0]
  def change
    add_column :gate_pass_inventories, :short_quantity, :integer, default: 0
  end
end
