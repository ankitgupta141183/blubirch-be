class AddColumnLiquidationRequestIdToLiquidation < ActiveRecord::Migration[6.0]
  def change
    add_column :liquidations, :liquidation_request_id, :integer, index: true
    add_column :liquidation_orders, :liquidation_request_id, :integer, index: true
  end
end
