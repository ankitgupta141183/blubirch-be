class CreateClientProcurementVendors < ActiveRecord::Migration[6.0]
  def change
    create_table :client_procurement_vendors do |t|
      t.integer :client_id
      t.string :vendor_code
      t.string :vendor_name
      t.string :vendor_type
      t.string :channel
      t.string :address_line_1
      t.string :address_line_2
      t.string :address_line_3
      t.string :city
      t.string :state
      t.string :country
      t.string :pincode
      t.string :vendor_poc_name
      t.string :vendor_poc_mobile
      t.string :vendor_poc_email
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :client_procurement_vendors, :client_id

  end
end
