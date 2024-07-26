class CreateForwardReplacements < ActiveRecord::Migration[6.0]
  def change
    create_table :forward_replacements do |t|
      t.references :distribution_center
      t.references :forward_inventory
      t.references :client
      t.references :client_sku_master
      t.references :vendor
      t.string :inward_reason_reference_document
      t.string :inward_reason_reference_document_number
      t.string :inward_reference_document
      t.string :inward_reference_document_number
      t.string :tag_number
      t.string :sku_code
      t.string :item_description
      t.string :grade
      t.string :supplier
      t.string :serial_number
      t.string :serial_number_2
      t.integer :status_id
      t.string :status
      t.jsonb :details
      t.float :item_price
      t.integer :replacement_location_id
      t.string :replacement_location
      t.date :replacement_date
      t.string :client_tag_number
      t.string :box_number
      t.boolean :is_active, default: true
      t.date :resolution_date
      t.string :reserve_id
      t.string :buyer
      t.integer :buyer_id
      t.float :selling_price
      t.float :payment_received
      t.integer :payment_status
      t.date :reserved_date
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
