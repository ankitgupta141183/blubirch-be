class AddLotPriceToLiquidationOrder < ActiveRecord::Migration[6.0]
  def change
    add_column :liquidation_orders, :lot_type_id, :integer
    add_column :liquidation_orders, :lot_type, :string
    add_column :liquidation_orders, :floor_price, :float
    add_column :liquidation_orders, :reserve_price, :float
    add_column :liquidation_orders, :buy_now_price, :float
    add_column :liquidation_orders, :increment_slab, :integer
    add_column :liquidations, :lot_type_id, :integer
    add_column :liquidations, :lot_type, :string
  end
end
