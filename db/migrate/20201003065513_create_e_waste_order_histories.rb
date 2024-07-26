class CreateEWasteOrderHistories < ActiveRecord::Migration[6.0]
  def change
    create_table :e_waste_order_histories do |t|
      t.references :e_waste_order
      t.integer :status_id
      t.string :status
    	t.jsonb :details
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
