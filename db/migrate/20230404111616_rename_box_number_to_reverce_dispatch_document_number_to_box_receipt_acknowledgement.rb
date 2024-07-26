class RenameBoxNumberToReverceDispatchDocumentNumberToBoxReceiptAcknowledgement < ActiveRecord::Migration[6.0]
  def change
    rename_column :box_receipt_acknowledgements, :box_number, :reverse_dispatch_document_number
    rename_column :damage_certificates, :box_number, :reverse_dispatch_document_number
  end
end
