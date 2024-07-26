class SkuEanSerializer < ActiveModel::Serializer

	attributes :id, :ean, :created_at, :updated_at, :client_sku_master

  def client_sku_master
  	SkuEan.includes(:client_sku_master).where("ean = ?", object.ean).collect(&:client_sku_master)
  end

end
