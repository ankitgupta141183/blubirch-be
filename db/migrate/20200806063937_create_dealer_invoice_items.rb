class CreateDealerInvoiceItems < ActiveRecord::Migration[6.0]
  def change
    create_table :dealer_invoice_items do |t|
      t.integer :dealer_invoice_id
      t.integer :dealer_order_inventory_id
      t.string :sku_master_code
      t.string :item_description
      t.float :mrp
      t.string :serial_number
      t.integer :client_sku_master_id
      t.string :hsn_code
      t.float :central_tax_percentage
      t.float :central_tax_amount
      t.float :state_tax_percentage
      t.float :sales_tax_amount
      t.float :inter_state_tax_percentage
      t.float :inter_state_tax_amount
      t.float :discount_percentage
      t.float :discount_price
      t.float :unit_price
      t.integer :quantity
      t.float :total_amount
      t.datetime :deleted_at
      t.timestamps
    end
  end
end
