class AddDetailsToPendingReceiptDocumentItems < ActiveRecord::Migration[6.0]
  def change
    add_column :pending_receipt_document_items, :details, :jsonb
    
    add_index :pending_receipt_document_items, :details, name: "pending_receipt_document_items_details", using: :gin
  end
end
