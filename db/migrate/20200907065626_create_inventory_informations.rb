class CreateInventoryInformations < ActiveRecord::Migration[6.0]
  def change
    create_table :inventory_informations do |t|
    	t.integer :inventory_id
    	t.integer :distribution_center_id
			t.integer :client_id
			t.integer :user_id
			t.string :tag_number
			t.jsonb :details
			t.datetime :deleted_at
			t.integer :gate_pass_id
			t.string :sku_code
			t.string :item_description
			t.integer :quantity
			t.string :client_tag_number
			t.string :disposition
			t.string :grade
			t.string :serial_number
			t.string :toat_number
			t.string :return_reason
			t.string :aisle_location
			t.float :item_price
			t.datetime :item_inward_date
			t.string :gate_pass_inventory_id
			t.string :sr_number
			t.string :serial_number_2
			t.integer :status_id
			t.string :status
			t.integer :client_category_id
			t.integer :vendor_return_id
			t.integer :repair_id
			t.integer :insurance_id
			t.integer :liquidation_id
			t.integer :redeploy_id
			t.integer :markdown_id
			t.integer :replacement_id
			t.string :vendor_return_status
			t.string :repair_status
			t.string :insurance_status
			t.string :liquidation_status
			t.string :redeploy_status
			t.string :markdown_status
			t.string :replacement_status
			t.datetime :vendor_return_created_at
			t.datetime :repair_created_at
			t.datetime :insurance_created_at
			t.datetime :liquidation_created_at
			t.datetime :redeploy_created_at
			t.datetime :markdown_created_at
			t.datetime :replacement_created_at
			t.datetime :vendor_return_updated_at
			t.datetime :repair_updated_at
			t.datetime :insurance_updated_at
			t.datetime :liquidation_updated_at
			t.datetime :redeploy_updated_at
			t.datetime :markdown_updated_at
			t.datetime :replacement_updated_at
			t.datetime :disptach_date

      t.timestamps
    end
    add_index :inventory_informations, :distribution_center_id
    add_index :inventory_informations, :inventory_id
    add_index :inventory_informations, :client_id
    add_index :inventory_informations, :user_id
    add_index :inventory_informations, :tag_number
  end
end
