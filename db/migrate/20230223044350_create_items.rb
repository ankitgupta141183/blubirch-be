class CreateItems < ActiveRecord::Migration[6.0]
  def change
    create_table :items do |t|
      t.string :tag_number
      t.string :sku_code
      t.string :sku_description
      t.jsonb :field_attributes
      t.string :reverse_dispatch_document_number
      t.string :serial_number_1
      t.string :serial_number_2
      t.string :location
      t.string :sub_location
      t.string :document_number
      t.string :document_type
      t.integer :document_type_id
      t.jsonb :details
      t.string :consignment_number
      t.string :client_category_name
      t.integer :client_category_id
      t.integer :quantity
      t.string :grade
      t.integer :grade_id
      t.string :disposition
      t.integer :disposition_id
      t.string :status
      t.integer :status_id
      t.float :mrp
      t.float :map
      t.integer :user_id
      t.integer :client_id
      t.integer :supplying_site_id
      t.integer :receiving_site_id
      t.string :supplying_site_name
      t.string :receiving_site_name
      t.string :inwarding_disposition
      t.string :inwarding_grade
      t.string :client_tag_number
      t.string :return_reason
      t.string :return_grade
      t.string :return_reamrks
      t.string :logistics_partner_name
      t.string :box_number
      t.string :box_condition
      t.boolean :is_sub_box
      t.string :box_status
      t.integer :box_status_id
      t.datetime :item_inwarded_date
      t.datetime :box_inwarded_date
      t.integer :parent_id
      t.string :grn_number
      t.datetime :grn_submitted_time
      t.string :grn_username
      t.integer :grn_user_id
      t.string :transporter_name
      t.string :transporter_contact_number
      t.string :transporter_vehicle_number
      t.datetime :logistics_receipt_date
      t.string :logistic_awb_number
      t.string :logistic_shipment_id
      t.string :logistic_tracking_id
      t.string :inward_type
      t.integer :inward_type_id
      t.string :ean
      t.boolean :is_serialized_item
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
