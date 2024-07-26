class CreateClientWarehouseVendors < ActiveRecord::Migration[6.0]
  def change
    create_table :client_warehouse_vendors do |t|
      t.integer :client_id
      t.string :vendor_code
      t.string :vendor_name
      t.string :address_line_1
      t.string :address_line_2
      t.string :address_line_3
      t.string :city
      t.string :state
      t.string :country
      t.string :pincode
      t.string :gst_number
      t.string :vendor_poc_name
      t.string :vendor_poc_mobile
      t.string :vendor_poc_email
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :client_warehouse_vendors, :vendor_code
    add_index :client_warehouse_vendors, :vendor_name
    add_index :client_warehouse_vendors, :deleted_at
    add_index :client_warehouse_vendors, :client_id

  end
end
