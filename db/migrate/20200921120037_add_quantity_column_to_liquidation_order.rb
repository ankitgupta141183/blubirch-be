class AddQuantityColumnToLiquidationOrder < ActiveRecord::Migration[6.0]
  def change
    add_column :liquidation_orders, :quantity, :integer
  end
end
