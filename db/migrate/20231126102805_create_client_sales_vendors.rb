class CreateClientSalesVendors < ActiveRecord::Migration[6.0]
  def change
    create_table :client_sales_vendors do |t|
      t.integer :client_id
      t.string :vendor_code
      t.string :vendor_name
      t.string :vendor_type
      t.string :channel
      t.boolean :authorized_dealer, default: false
      t.boolean :ewaster_certified, default: false
      t.boolean :is_contracted, default: false
      t.string :preferred_locations, array: true
      t.string :preferred_categories, array: true
      t.string :vendor_poc_name
      t.string :vendor_poc_mobile
      t.string :vendor_poc_email
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :client_sales_vendors, :client_id
    
  end
end
