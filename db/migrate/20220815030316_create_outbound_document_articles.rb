class CreateOutboundDocumentArticles < ActiveRecord::Migration[6.0]
  def change
    create_table :outbound_document_articles do |t|
      t.integer :distribution_center_id
      t.integer :client_id
      t.integer :user_id
      t.integer :outbound_document_id
      t.integer :client_category_id
      t.string :client_category_name
      t.string :sku_code
      t.string :item_description
      t.integer :quantity
      t.integer :outwarded_quantity
      t.integer :status_id
      t.string :status
      t.string :brand
      t.integer :client_sku_master_id
      t.string :ean
      t.jsonb :details
      t.string :merchandise_category
      t.string :merch_cat_desc
      t.string :line_item
      t.string :document_type
      t.string :scan_id
      t.string :item_number
      t.string :aisle_location
      t.text :sku_eans, array: true, default: []
      t.integer :short_quantity, default: 0
      t.string :imei_flag
      t.datetime :deleted_at 

      t.timestamps
    end
    add_index :outbound_document_articles, :distribution_center_id
    add_index :outbound_document_articles, :client_id
    add_index :outbound_document_articles, :user_id
    add_index :outbound_document_articles, :status_id
    add_index :outbound_document_articles, :outbound_document_id
    add_index :outbound_document_articles, :client_sku_master_id
  end
end
