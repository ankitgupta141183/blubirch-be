class CreateReplacementHistories < ActiveRecord::Migration[6.0]
  def change
    create_table :replacement_histories do |t|
      t.integer :replacement_id
      t.integer :status_id
      t.jsonb :details
      t.datetime :deleted_at
      t.timestamps
    end

    add_index :replacement_histories, :replacement_id
    add_index :replacement_histories, :status_id
  end
end
