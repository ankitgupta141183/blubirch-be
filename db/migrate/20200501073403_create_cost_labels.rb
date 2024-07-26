class CreateCostLabels < ActiveRecord::Migration[6.0]
  def change
    create_table :cost_labels do |t|
      t.integer :distribution_center_id
      t.integer :channel_id
      t.string :label
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :cost_labels, :distribution_center_id
    add_index :cost_labels, :channel_id
  end
end
