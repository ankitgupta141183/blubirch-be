class AddDistributionCenterIdAndBenchMarkPriceToLiquidationOrder < ActiveRecord::Migration[6.0]
  def change
    add_column :liquidation_orders, :distribution_center_id, :integer
    add_column :liquidation_orders, :bench_mark_price, :float
    add_index :liquidation_orders, :distribution_center_id
  end
end
