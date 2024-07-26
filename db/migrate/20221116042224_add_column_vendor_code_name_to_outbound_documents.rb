class AddColumnVendorCodeNameToOutboundDocuments < ActiveRecord::Migration[6.0]
  def change
    add_column :outbound_documents, :vendor_code, :string
    add_column :outbound_documents, :vendor_name, :string
    add_column :outbound_documents, :original_invoice, :string
  end
end
