class CreateRentalHistories < ActiveRecord::Migration[6.0]
  def change
    create_table :rental_histories do |t|
      t.integer :rental_id
      t.integer :status_id
      t.jsonb :details
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :rental_histories, :rental_id
  end
end
