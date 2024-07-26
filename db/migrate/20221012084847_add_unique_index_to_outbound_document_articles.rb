class AddUniqueIndexToOutboundDocumentArticles < ActiveRecord::Migration[6.0]
  def change
    add_index(:outbound_document_articles, [:outbound_document_id, :item_number, :sku_code, :quantity], :unique => true, :name => 'by_item_quantity_sku_outbound_document')
  end
end
