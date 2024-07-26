class CreateRepairHistories < ActiveRecord::Migration[6.0]
  def change
    create_table :repair_histories do |t|
      t.integer :repair_id
      t.integer :status_id
      t.json :details
      t.datetime :deleted_at

      t.timestamps
    end
    remove_column :repairs, :is_active, :boolean
  end
end
