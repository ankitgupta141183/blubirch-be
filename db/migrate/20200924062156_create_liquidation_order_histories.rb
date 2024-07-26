class CreateLiquidationOrderHistories < ActiveRecord::Migration[6.0]
  def change
    create_table :liquidation_order_histories do |t|
      t.references :liquidation_order
      t.integer :status_id
      t.string :status
    	t.jsonb :details
      t.datetime :deleted_at
      
      t.timestamps
    end
  end
end
