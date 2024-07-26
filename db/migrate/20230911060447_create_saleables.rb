class CreateSaleables < ActiveRecord::Migration[6.0]
  #inventory_id
  #tag_number
  #details
  #article_sku
  #article_description
  #status_id
  #status
  #is_active
  #selling_price
  #payment_received
  #reserve_date date
  #reserve_number
  #benchmark_date date
  #vendor_code
  #vendor_name
  #vendor_id
  def change
    create_table :saleables do |t|
      t.references :inventory
      t.references :vendor
      t.references :sale_order
      t.string :tag_number
      t.jsonb :details
      t.string :article_sku
      t.text :article_description
      t.integer :status_id
      t.string :status
      t.boolean :is_active, :default => true
      t.float :selling_price
      t.float :payment_received
      t.date :reserve_date
      t.string :reserve_number
      t.date :benchmark_date
      t.string :vendor_code
      t.string :vendor_name
      t.string :payment_status
      t.timestamps
    end
  end
end
