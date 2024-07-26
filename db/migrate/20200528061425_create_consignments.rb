class CreateConsignments < ActiveRecord::Migration[6.0]
  def change
    create_table :consignments do |t|

      t.string :outward_document_number
      t.string :driver_name
      t.string :driver_contact_number
      t.string :truck_number
      t.integer :logistics_partner_id
      t.integer :user_id
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :consignments, :logistics_partner_id
    add_index :consignments, :user_id
  end
end
