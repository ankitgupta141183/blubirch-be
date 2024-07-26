class CreatePendingDispositions < ActiveRecord::Migration[6.0]
  def change
    create_table :pending_dispositions do |t|

      t.integer :distribution_center_id
      t.integer :inventory_id
      t.string :tag_number
      t.jsonb :details
      t.integer :status_id
      t.string :status
      t.integer :client_sku_master_id
      t.string :sku_code
      t.text :item_description
      t.string :grade
      t.string :vendor
      t.float :item_price
      t.string :sr_number
      t.string :serial_number
      t.string :serial_number_2
      t.string :rgp_number
      t.string :aisle_location
      t.integer :replacement_location_id
      t.string :replacement_location
      t.string :toat_number
      t.string :client_tag_number
      t.string :client_id
      t.string :gate_pass_id
      t.string :return_reason
      t.datetime :deleted_at
      t.timestamps
    end
  end
end
