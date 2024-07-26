class CreateForwardInventories < ActiveRecord::Migration[6.0]
  def change
    create_table :forward_inventories do |t|
      t.references :distribution_center
      t.references :client
      t.references :client_category
      t.references :client_sku_master
      t.references :sub_location
      t.references :vendor
      t.string :inward_reason_reference_document
      t.string :inward_reason_reference_document_number
      t.string :inward_reference_document
      t.string :inward_reference_document_number
      t.string :tag_number
      t.string :sku_code
      t.string :item_description
      t.string :serial_number
      t.string :serial_number_2
      t.jsonb :details
      t.integer :quantity
      t.integer :inwarded_quantity
      t.integer :outwarded_quantity
      t.string :client_tag_number
      t.integer :disposition_id
      t.string :disposition
      t.integer :status_id
      t.string :status
      t.string :grade
      t.string :brand
      t.string :box_number
      t.string :return_reason
      t.string :supplier
      t.float :item_price
      t.float :mrp
      t.float :map
      t.float :asp
      t.float :purchase_price
      t.string :short_reason
      t.integer :short_quantity
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
