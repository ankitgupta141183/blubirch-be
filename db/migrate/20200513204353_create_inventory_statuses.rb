class CreateInventoryStatuses < ActiveRecord::Migration[6.0]
  def change
    create_table :inventory_statuses do |t|
    	t.integer :distribution_center_id
    	t.integer :inventory_id
    	t.integer :status_id
    	t.integer :user_id
    	t.jsonb :details
    	t.boolean :is_active, default: true
    	t.datetime :deleted_at

      t.timestamps
    end
    add_index :inventory_statuses, :distribution_center_id
    add_index :inventory_statuses, :inventory_id
    add_index :inventory_statuses, :status_id
    add_index :inventory_statuses, :user_id
  end
end
