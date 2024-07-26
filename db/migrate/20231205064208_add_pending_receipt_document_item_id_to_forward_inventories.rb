class AddPendingReceiptDocumentItemIdToForwardInventories < ActiveRecord::Migration[6.0]
  def change
    add_column :forward_inventories, :pending_receipt_document_item_id, :integer
  end
end
