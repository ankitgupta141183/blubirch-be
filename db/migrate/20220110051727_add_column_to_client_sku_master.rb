class AddColumnToClientSkuMaster < ActiveRecord::Migration[6.0]
  def change
    add_column :client_sku_masters, :scannable_flag, :boolean, default: false
    add_column :client_sku_masters, :category_code, :string
    add_column :client_sku_masters, :imei_flag, :string
    add_column :client_sku_masters, :sku_component, :string, array: true, default: []
    add_column :client_sku_masters, :ancestry, :string
    add_index :client_sku_masters, :ancestry
  end
end