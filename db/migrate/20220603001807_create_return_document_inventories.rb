class CreateReturnDocumentInventories < ActiveRecord::Migration[6.0]
  def change
    create_table :return_document_inventories do |t|
      t.string :sku_code          
      t.string :scan_id               
      t.integer :quantity              
      t.string :item_description      
      t.string :merchandise_category
      t.string :merch_cat_desc  
      t.string :line_item        
      t.integer :client_category_id
      t.string :brand
      t.string :client_category_name
      t.integer :client_sku_master_id  
      t.string :item_number           
      t.integer :inwarded_quantity
      t.integer :status_id
      t.string :status           
      t.integer :distribution_center_id
      t.integer :client_id
      t.integer :user_id               
      t.jsonb :details
      t.string :pickslip_number
      t.string :imei_flag              
      t.integer :return_document_id
      t.text :sku_eans, array: true, default: []
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :return_document_inventories, :client_category_id
    add_index :return_document_inventories, :distribution_center_id
    add_index :return_document_inventories, :user_id
    add_index :return_document_inventories, :status_id
    add_index :return_document_inventories, :return_document_id
  end
end
