class CreateRestockHistories < ActiveRecord::Migration[6.0]
  def change
    create_table :restock_histories do |t|
      t.integer :restock_id
      t.integer :status_id
      t.jsonb :details
      t.datetime :deleted_at
      t.timestamps
    end
  end
end
