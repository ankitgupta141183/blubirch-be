class AddBrandInGatepassInventories < ActiveRecord::Migration[6.0]
  def change
  	add_column :gate_pass_inventories, :brand, :string
  end
end
