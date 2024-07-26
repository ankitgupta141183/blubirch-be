class CreateEWasteHistories < ActiveRecord::Migration[6.0]
  def change
    create_table :e_waste_histories do |t|
      t.integer :e_waste_id
      t.integer :status_id
      t.string :status
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :e_waste_histories, :e_waste_id
  end
end
