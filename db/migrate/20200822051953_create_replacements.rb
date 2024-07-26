class CreateReplacements < ActiveRecord::Migration[6.0]
  def change
    create_table :replacements do |t|

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
      t.string :call_log_id
      t.datetime :call_log_date
      t.text :call_log_remarks
      t.float :item_price
      t.text :action_remark
      t.string :sr_number1
      t.string :sr_number2
      t.string :rgp_number
      t.integer :replacement_location_id
      t.string :replacement_location
      t.text :replacement_remark
      t.datetime :replacement_date
      t.string :blubirch_call_log_id
      t.datetime :deleted_at
      t.timestamps
    end

    add_index :replacements, :inventory_id
    add_index :replacements, :distribution_center_id
    add_index :replacements, :status_id
    add_index :replacements, :client_sku_master_id
    add_index :replacements, :replacement_location_id
  end
end
