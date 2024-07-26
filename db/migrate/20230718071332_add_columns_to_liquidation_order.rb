class AddColumnsToLiquidationOrder < ActiveRecord::Migration[6.0]
  def change
    add_column :liquidation_orders, :maximum_lots_per_buyer, :integer
    add_column :liquidation_orders, :moq_order_id,           :integer
    add_column :liquidation_orders, :lot_order,              :integer
  end
end
