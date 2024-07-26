class CreatePendingReceiptDocuments < ActiveRecord::Migration[6.0]
  def change
    create_table :pending_receipt_documents do |t|
      t.string :batch_number
      t.string :inward_reference_document_type
      t.string :inward_reference_document_number
      t.string :inward_reason_reference_document_type
      t.string :inward_reason_reference_document_number
      t.string :consignee_reference_document_number
      t.string :consignee_reference_document_type
      t.string :vendor_reference_document_number
      t.string :vendor_reference_document_type
      t.string :status
      t.integer :status_id
      t.integer :user_id
      t.string :receiving_organization
      t.string :supplier_organization
      t.string :supplying_site_code
      t.string :receiving_site_code
      t.integer :supplying_site_id
      t.integer :receiving_site_id
      t.boolean :is_box_mapped
      t.date :inward_reference_document_date
      t.date :inward_reason_reference_document_date
      t.date :consignee_reference_document_date
      t.datetime :deleted_at

      t.timestamps
    end
    
    add_index :pending_receipt_documents, :inward_reference_document_number, name: "prd_inward_reference_document_number"
    add_index :pending_receipt_documents, :inward_reason_reference_document_number, name: "prd_inward_reason_reference_document_number" 
    add_index :pending_receipt_documents, :consignee_reference_document_number, name: "prd_consignee_reference_document_number"
    add_index :pending_receipt_documents, :vendor_reference_document_number, name: "prd_vendor_reference_document_number"
    add_index :pending_receipt_documents, :inward_reference_document_date, name: "prd_inward_reference_document_date"
    add_index :pending_receipt_documents, :inward_reason_reference_document_date, name: "prd_inward_reason_reference_document_date"
    add_index :pending_receipt_documents, :consignee_reference_document_date, name: "prd_consignee_reference_document_date"
    add_index :pending_receipt_documents, :status
    add_index :pending_receipt_documents, :status_id
    add_index :pending_receipt_documents, :supplying_site_id
    add_index :pending_receipt_documents, :receiving_site_id
    add_index :pending_receipt_documents, :supplying_site_code
    add_index :pending_receipt_documents, :receiving_site_code
  end
end
