class CreateVendorReturns < ActiveRecord::Migration[6.0]
  def change
    create_table :vendor_returns do |t|

      t.integer :distribution_center_id
      t.integer :inventory_id
      t.integer :claim_id
      t.integer :claim_action_id
      t.string :tag_number
      t.jsonb :details
      t.integer :status_id
      t.boolean :is_active
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :vendor_returns, :distribution_center_id
    add_index :vendor_returns, :inventory_id
    add_index :vendor_returns, :status_id
    add_index :vendor_returns, :claim_id
    add_index :vendor_returns, :claim_action_id
  end
end
