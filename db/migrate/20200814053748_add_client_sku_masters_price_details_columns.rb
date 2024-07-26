class AddClientSkuMastersPriceDetailsColumns < ActiveRecord::Migration[6.0]
  def change
  	add_column :client_sku_masters, :ean, :string
  	add_column :client_sku_masters, :upc, :string
  	add_column :client_sku_masters, :sku_description, :string
  	add_column :client_sku_masters, :item_type, :string
  	add_column :client_sku_masters, :mrp, :float
  	add_column :client_sku_masters, :brand, :string
  	add_column :client_sku_masters, :model, :string
  end

end
