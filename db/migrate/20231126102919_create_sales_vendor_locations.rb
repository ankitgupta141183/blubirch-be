class CreateSalesVendorLocations < ActiveRecord::Migration[6.0]
  def change
    create_table :sales_vendor_locations do |t|
      t.integer :client_id
      t.string :vendor_code
      t.string :vendor_name
      t.integer :client_sales_vendor_id
      t.string :address_type
      t.string :address_line_1
      t.string :address_line_2
      t.string :address_line_3
      t.string :city
      t.string :state
      t.string :pincode
      t.string :gst_number
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :sales_vendor_locations, :vendor_code
    add_index :sales_vendor_locations, :vendor_name
    add_index :sales_vendor_locations, :client_sales_vendor_id
    add_index :sales_vendor_locations, :deleted_at
    add_index :sales_vendor_locations, :client_id

  end
end
