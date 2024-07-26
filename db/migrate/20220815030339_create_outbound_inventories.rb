class CreateOutboundInventories < ActiveRecord::Migration[6.0]
  def change
    create_table :outbound_inventories do |t|
      t.integer :distribution_center_id
      t.integer :client_id
      t.integer :user_id
      t.string :tag_number
      t.jsonb :details
      t.integer :outbound_document_id
      t.integer :outbound_document_article_id
      t.string :sku_code
      t.string :item_description
      t.integer :quantity
      t.integer :short_quantity
      t.string :client_tag_number
      t.string :aisle_location
      t.string :serial_number
      t.string :grade
      t.string :imei1
      t.string :imei2
      t.integer :status_id
      t.string :status
      t.integer :client_category_id
      t.boolean :is_synced, default: false
      t.boolean :is_pushed, default: false
      t.datetime :pushed_at
      t.datetime :synced_at 
      t.string :synced_time
      t.string :scanned_time
      t.string :short_reason
      t.boolean :is_error_response_received , default: false
      t.boolean :is_error, default: false
      t.string :error_string
      t.boolean :is_forward, default: true
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :outbound_inventories, :distribution_center_id
    add_index :outbound_inventories, :client_id
    add_index :outbound_inventories, :user_id
    add_index :outbound_inventories, :tag_number, unique: true
    add_index :outbound_inventories, :outbound_document_id
    add_index :outbound_inventories, :outbound_document_article_id
    add_index :outbound_inventories, :status_id

  end
end
