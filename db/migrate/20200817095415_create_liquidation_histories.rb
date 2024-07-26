class CreateLiquidationHistories < ActiveRecord::Migration[6.0]
  def change
    create_table :liquidation_histories do |t|
    	t.integer :liquidation_id
    	t.integer :status_id
    	t.string :status
    	t.datetime :deleted_at
    	t.timestamps
    end
  end
end
