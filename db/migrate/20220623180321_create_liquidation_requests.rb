class CreateLiquidationRequests < ActiveRecord::Migration[6.0]
  def change
    create_table :liquidation_requests do |t|
      t.integer :total_items
      t.integer :graded_items
      t.string :status
      t.integer :status_id
      t.string :request_id
      t.timestamps
    end
  end
end
