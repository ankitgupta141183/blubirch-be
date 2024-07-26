class CreatePurchaseOrderReceiptChallans < ActiveRecord::Migration[6.0]
  def change
    create_table :purchase_order_receipt_challans do |t|
      t.string :rc_date, index: true
      t.string :rc_number
      t.string :item_type
      t.references :oms_item, index: true
      t.references :oms, index: true
      t.string :tag_number, index: true
      t.string :sku_code, index: true
      t.text :item_description
      t.string :serial_number, index: true
      t.decimal :price
      t.integer :quantity
      t.decimal :total_price
      t.string :status, index: true
      t.jsonb :details, default: {}
      t.timestamps
    end
  end
end
