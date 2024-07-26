class AddFieldsToLiquidationOrders < ActiveRecord::Migration[6.0]
  def change
    add_reference :liquidation_orders, :created_by, foreign_key: { to_table: :users }
    add_reference :liquidation_orders, :updated_by, foreign_key: { to_table: :users }
  end
end
