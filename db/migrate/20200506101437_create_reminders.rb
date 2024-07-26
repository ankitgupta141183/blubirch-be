class CreateReminders < ActiveRecord::Migration[6.0]
  def change
    create_table :reminders do |t|
      t.integer :status_id
      t.integer :client_category_id
      t.integer :customer_return_reason_id
      t.integer :sku_master_id
      t.jsonb :details, default: {}
      t.boolean :approval_required
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :reminders, :status_id
    add_index :reminders, :client_category_id
    add_index :reminders, :customer_return_reason_id
    add_index :reminders, :sku_master_id
    add_index :reminders, :details, using: :gin
  end
end
