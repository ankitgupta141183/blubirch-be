class CreateForwardInventoryStatuses < ActiveRecord::Migration[6.0]
  def change
    create_table :forward_inventory_statuses do |t|
      t.references :distribution_center
      t.references :forward_inventory
      t.references :user
      t.integer :status_id
      t.jsonb :details
      t.boolean :is_active, default: true
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
