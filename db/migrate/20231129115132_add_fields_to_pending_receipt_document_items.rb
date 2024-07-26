class AddFieldsToPendingReceiptDocumentItems < ActiveRecord::Migration[6.0]
  def change
    add_column :pending_receipt_document_items, :reason_for_deletion, :string
    add_column :pending_receipt_document_items, :delete_remarks, :string
    add_column :pending_receipt_document_items, :previous_status, :string
    add_column :pending_receipt_document_items, :grn_number, :string
    add_column :pending_receipt_document_items, :grn_submitted_date, :date
    add_column :pending_receipt_document_items, :grn_submitted_user_id, :integer
    add_column :pending_receipt_document_items, :grn_submitted_user_name, :string
    
    add_column :inventories, :pending_receipt_document_item_id, :integer
    
    add_index :pending_receipt_document_items, :grn_number
  end
end
