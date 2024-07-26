class CreateInvoiceInventoryDetails < ActiveRecord::Migration[6.0]
  def change
    create_table :invoice_inventory_details do |t|
      t.integer :invoice_id
      t.integer :client_category_id
      t.integer :client_sku_master_id
      t.integer :quantity
      t.integer :return_quantity
      t.float :item_price
      t.float :total_price
      t.jsonb :details
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :invoice_inventory_details, :invoice_id
    add_index :invoice_inventory_details, :client_category_id
    add_index :invoice_inventory_details, :client_sku_master_id
  end
end
