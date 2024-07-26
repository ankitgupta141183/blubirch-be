class CreateQuotations < ActiveRecord::Migration[6.0]
  def change
    create_table :quotations do |t|
    	t.references  :vendor_master
      t.references  :liquidation_order
      t.float :expected_price
      t.float :settlement_price
      t.jsonb :details

      t.timestamps
    end
  end
end