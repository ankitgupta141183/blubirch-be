class CreateCannibalizationHistories < ActiveRecord::Migration[6.0]
  def change
    create_table :cannibalization_histories do |t|
      t.integer :cannibalization_id
      t.integer :status_id
      t.jsonb :details, default: {}
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :cannibalization_histories, :cannibalization_id
  end
end
