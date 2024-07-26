class AddLiquidationOrderIdInLiquidationOrders < ActiveRecord::Migration[6.0]
  def change
    add_column :liquidation_orders, :liquidation_order_id, :integer
  end
end
