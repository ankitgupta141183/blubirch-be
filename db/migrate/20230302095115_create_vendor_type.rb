class CreateVendorType < ActiveRecord::Migration[6.0]
  def change
    create_table :vendor_types do |t|
      t.references :vendor_master
      t.integer    :vendor_type_id
      t.string     :vendor_type
    end

    add_index :vendor_types, [:vendor_master_id, :vendor_type_id], unique: true
  end
end
