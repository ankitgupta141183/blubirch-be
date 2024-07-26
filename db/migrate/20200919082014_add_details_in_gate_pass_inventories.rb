class AddDetailsInGatePassInventories < ActiveRecord::Migration[6.0]
  def change
    add_column :gate_pass_inventories, :details, :jsonb
  end
end
