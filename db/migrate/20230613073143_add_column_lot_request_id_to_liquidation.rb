class AddColumnLotRequestIdToLiquidation < ActiveRecord::Migration[6.0]
  change_table :liquidation_orders, bulk: true do |t|
    t.string :lot_request_id
  end
end
