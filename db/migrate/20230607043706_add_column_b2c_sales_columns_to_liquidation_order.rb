class AddColumnB2cSalesColumnsToLiquidationOrder < ActiveRecord::Migration[6.0]
  change_table :liquidation_orders, bulk: true do |t|
    t.string :buyer_name
    t.text :buyer_address_1
    t.text :buyer_address_2
    t.string :buyer_city
    t.string :buyer_state
  end
end
