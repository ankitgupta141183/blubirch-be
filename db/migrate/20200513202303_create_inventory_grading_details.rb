class CreateInventoryGradingDetails < ActiveRecord::Migration[6.0]
  def change
    create_table :inventory_grading_details do |t|
    	t.integer :distribution_center_id
    	t.integer :inventory_id
    	t.integer :grade_id
    	t.integer :user_id
    	t.jsonb :details
    	t.boolean :is_active, default: true
    	t.datetime :deleted_at

      t.timestamps
    end
    add_index :inventory_grading_details, :distribution_center_id
    add_index :inventory_grading_details, :inventory_id
    add_index :inventory_grading_details, :grade_id
    add_index :inventory_grading_details, :user_id
  end
end
