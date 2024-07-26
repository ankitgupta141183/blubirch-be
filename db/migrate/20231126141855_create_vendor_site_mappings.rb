class CreateVendorSiteMappings < ActiveRecord::Migration[6.0]
  def change
    create_table :vendor_site_mappings do |t|
      t.integer :vendor_mappable_id
      t.string :vendor_mappable_type
      t.integer :distribution_center_id
      t.string :distribution_center_code
      t.string :distribution_center_name
      t.string :vendor_location
      t.string :vendor_location_gst_number
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :vendor_site_mappings, :vendor_mappable_id
    add_index :vendor_site_mappings, :vendor_mappable_type
    add_index :vendor_site_mappings, :distribution_center_id
    add_index :vendor_site_mappings, :distribution_center_code
    add_index :vendor_site_mappings, :distribution_center_name
    add_index :vendor_site_mappings, :deleted_at
    
  end
end
