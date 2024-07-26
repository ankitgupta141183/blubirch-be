class CreatePendingReceiptDocumentItems < ActiveRecord::Migration[6.0]
  def change
    create_table :pending_receipt_document_items do |t|
      t.references :client
      t.references :distribution_center
      t.references :client_category
      t.references :client_sku_master
      t.references :vendor
      t.integer :pending_receipt_document_id
      t.string :box_number
      t.string :tag_number
      t.string :ean
      t.string :brand
      t.string :grade
      t.string :model
      t.string :scan_indicator
      t.string :imei_flag
      t.string :serial_number1
      t.string :serial_number2
      t.string :sku_code
      t.string :sku_description
      t.string :category_code
      t.jsonb :category_details
      t.jsonb :item_attributes
      t.integer :quantity
      t.string :status
      t.integer :status_id
      t.integer :user_id
      t.json :images
      t.json :videos
      t.jsonb :test_questions
      t.string :test_user
      t.date :test_date
      t.string :test_report_number
      t.string :test_report
      t.float :mrp
      t.float :asp
      t.float :sales_price
      t.float :map
      t.float :purchase_price
      t.integer :return_item_id
      t.string :return_request_id
      t.string :return_sub_request_id
      t.string :return_type
      t.string :return_request_sub_type
      t.string :return_reason
      t.date :return_request_date
      t.string :return_sub_reason
      t.string :return_channel
      t.string :customer_name
      t.string :customer_mobile
      t.string :customer_email
      t.string :customer_address_1
      t.string :customer_address_2
      t.string :customer_address_3
      t.string :customer_city
      t.string :customer_state
      t.string :customer_pincode
      t.string :type_of_damage
      t.string :type_of_loss
      t.float :estimated_loss
      t.float :estimated_salvage_value
      t.date :incident_date
      t.string :incident_location
      t.boolean :vendor_responsible_for_damage, default: false
      t.json :incident_related_docs
      t.string :incident_report_number
      t.string :incident_report
      t.string :incident_damage_certificate
      t.string :sales_invoice_number
      t.date :sales_invoice_date
      t.string :customer_delivery_receipt_number
      t.string :customer_delivery_receipt_attachment
      t.date :customer_delivery_receipt_date
      t.string :installation_attachment
      t.date :installation_date
      t.string :purchase_invoice_number
      t.date :purchase_invoice_date
      t.string :sales_invoice_attachment
      t.date :purchase_date
      t.string :doa_certificate_attachment
      t.string :doa_certificate_number
      t.date :doa_certificate_date
      t.date :doa_validity_date
      t.string :disposition
      t.string :disposition_stage
      t.string :receiving_site
      t.string :supplying_site
      t.string :receiving_organization
      t.string :supplier_organization
      t.integer :supplying_site_id
      t.integer :receiving_site_id
      t.boolean :brand_approval_required, default: false
      t.boolean :buyer_available, default: false
      t.boolean :grading_required, default: false
      t.string :purchase_location
      t.datetime :deleted_at

      t.timestamps
    end
    
    add_index :pending_receipt_document_items, :pending_receipt_document_id, name: "prd_items_pending_receipt_document_id"
    add_index :pending_receipt_document_items, :tag_number
    add_index :pending_receipt_document_items, :box_number
    add_index :pending_receipt_document_items, :grade
    add_index :pending_receipt_document_items, :disposition
    add_index :pending_receipt_document_items, :sku_code
    add_index :pending_receipt_document_items, :supplying_site_id
    add_index :pending_receipt_document_items, :receiving_site_id
    add_index :pending_receipt_document_items, :category_details, name: "pending_receipt_document_items_category_details", using: :gin
    add_index :pending_receipt_document_items, :item_attributes, name: "pending_receipt_document_items_item_attributes", using: :gin
    add_index :pending_receipt_document_items, :test_questions, name: "pending_receipt_document_items_test_questions", using: :gin
  end
end
