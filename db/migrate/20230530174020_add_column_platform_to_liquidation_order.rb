class AddColumnPlatformToLiquidationOrder < ActiveRecord::Migration[6.0]
  def change
    add_column :liquidation_orders, :platform, :integer
    add_column :liquidation_orders, :publish_price, :float
    add_column :liquidation_orders, :discount, :float
  end
end
