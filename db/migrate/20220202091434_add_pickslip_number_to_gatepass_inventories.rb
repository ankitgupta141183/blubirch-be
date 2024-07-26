class AddPickslipNumberToGatepassInventories < ActiveRecord::Migration[6.0]
  def change
    add_column :gate_pass_inventories, :pickslip_number, :string
  end
end
