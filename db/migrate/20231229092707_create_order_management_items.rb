class CreateOrderManagementItems < ActiveRecord::Migration[6.0]
  def change
    create_table :order_management_items do |t|
      t.string :rrd_creation_date, index: true
      t.string :reason_reference_document_no
      t.string :reference_document_no
      t.references :inventory, index: true, polymorphic: true
      t.string :item_type
      t.references :oms, index: true
      t.string :tag_number, index: true
      t.string :sku_code, index: true
      t.text :item_description
      t.string :serial_number, index: true
      t.decimal :price
      t.integer :quantity
      t.decimal :total_price
      t.string :status, index: true
      t.date :invoice_creation_date
      t.string :invoice_no, index: true
      t.jsonb :details, default: {}
      t.timestamps
    end
  end
end
