class CreateWarehouseConsignments < ActiveRecord::Migration[6.0]
  def change
    create_table :warehouse_consignments do |t|
      t.string :transporter
      t.string :truck_receipt_number
      t.string :vehicle_number
      t.string :driver_name
      t.string :driver_contact_number
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
