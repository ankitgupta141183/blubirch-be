class CreateReturnInventoryInformations < ActiveRecord::Migration[6.0]
  def change
    create_table :return_inventory_informations do |t|
      t.string :reference_document
      t.string :reference_document_number
      t.string :sku_code
      t.string :sku_description
      t.string :serial_number
      t.integer :quantity
      t.datetime :order_date
      t.float :item_value
      t.float :total_amount
      t.string :customer_name
      t.string :customer_email
      t.string :customer_phone
      t.string :customer_address_line1
      t.string :customer_address_line2
      t.string :customer_address_line3
      t.string :customer_city
      t.string :customer_state
      t.string :customer_country
      t.string :customer_pincode
      t.string :status
      t.integer :status_id
      t.integer :user_id
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :return_inventory_informations, :reference_document_number, name: "return_inventory_info_ref_doc_number"
    add_index :return_inventory_informations, :sku_code, name: "return_inventory_info_sku_code"
    add_index :return_inventory_informations, :serial_number, name: "return_inventory_info_serial_number"
    add_index :return_inventory_informations, :order_date, name: "return_inventory_info_order_date"
    add_index :return_inventory_informations, :status, name: "return_inventory_info_status"
    add_index :return_inventory_informations, :status_id, name: "return_inventory_info_status_id"
    add_index :return_inventory_informations, :user_id, name: "return_inventory_info_user_id"
    
  end
end
