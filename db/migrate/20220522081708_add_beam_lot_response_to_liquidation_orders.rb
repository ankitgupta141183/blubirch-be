class AddBeamLotResponseToLiquidationOrders < ActiveRecord::Migration[6.0]
  def change
    add_column :liquidation_orders, :beam_lot_response, :text
    add_column :liquidation_orders, :beam_lot_id, :integer
  end
end
