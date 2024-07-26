class CreateCompanyStocks < ActiveRecord::Migration[6.0]
  def change
    create_table :company_stocks do |t|
      t.integer :client_id
      t.integer :client_sku_master_id
      t.string :serial_number
      t.integer :quantity
      t.integer :sold_quantity
      t.string :sku_code
      t.integer :category_id
      t.string :category_name
      t.string :item_description
      t.jsonb :details
      t.float :mrp
      t.string :brand
      t.string :model
      t.string :hsn_code
      t.float :tax_percentage
      t.string :location
      t.integer :status_id
      t.string :status
      t.integer :user_id
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :company_stocks, :client_id
    add_index :company_stocks, :client_sku_master_id
    add_index :company_stocks, :category_id
    add_index :company_stocks, :status_id
    add_index :company_stocks, :user_id
  end
end
