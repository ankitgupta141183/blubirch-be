class CreateLiquidationOrderVendors < ActiveRecord::Migration[6.0]
  def change
    create_table :liquidation_order_vendors do |t|
      t.references  :liquidation_order
      t.references  :vendor_master

      t.timestamps
    end
  end
end
