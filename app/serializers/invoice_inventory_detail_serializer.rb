class InvoiceInventoryDetailSerializer < ActiveModel::Serializer
	  
  attributes :id, :quantity, :return_quantity, :client_category, :invoice, :client_sku_master, :item_price, :total_price, :details, :deleted_at, :created_at, :updated_at


end
