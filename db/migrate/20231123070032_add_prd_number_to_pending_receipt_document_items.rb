class AddPrdNumberToPendingReceiptDocumentItems < ActiveRecord::Migration[6.0]
  def change
    add_column :pending_receipt_document_items, :prd_number, :string
    add_column :pending_receipt_document_items, :toat_number, :string
    
    add_index :pending_receipt_document_items, :prd_number
  end
end
