class AddPriceColumnToClientSkuMasters < ActiveRecord::Migration[6.0]
  def change
    add_column :client_sku_masters, :asp, :float
    add_column :client_sku_masters, :map, :float
    add_column :client_sku_masters, :supplier, :string
    add_column :return_inventory_informations, :mrp, :float
    add_column :return_inventory_informations, :asp, :float
    add_column :return_inventory_informations, :map, :float
    add_column :return_inventory_informations, :supplier, :string
    add_column :return_inventory_informations, :category_details, :jsonb
    add_column :return_inventory_informations, :brand, :string
    add_column :return_items, :mrp, :float
    add_column :return_items, :asp, :float
    add_column :return_items, :map, :float
    add_column :return_items, :supplier, :string
    add_column :return_items, :category_details, :jsonb
    add_column :return_items, :brand, :string
  end
end
