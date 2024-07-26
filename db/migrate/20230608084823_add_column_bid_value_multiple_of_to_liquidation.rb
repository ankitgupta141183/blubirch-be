class AddColumnBidValueMultipleOfToLiquidation < ActiveRecord::Migration[6.0]

  change_table :liquidation_orders, bulk: true do |t|
    t.integer :bid_value_multiple_of
  end
end
