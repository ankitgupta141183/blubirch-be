class CreateVendorMaster < ActiveRecord::Migration[6.0]
  def change
    create_table :vendor_masters do |t|
      t.string :vendor_type
      t.string :vendor_code
      t.string :vendor_name
      t.string :vendor_address
      t.string :vendor_city
      t.string :vendor_state
      t.string :vendor_pin
      t.string :vendor_email
      t.string :vendor_phone
    end
  end
end
