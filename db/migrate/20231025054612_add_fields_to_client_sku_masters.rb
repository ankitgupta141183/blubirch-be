class AddFieldsToClientSkuMasters < ActiveRecord::Migration[6.0]
  def change
    add_column :client_sku_masters, :sku_type_id, :integer
    add_column :client_sku_masters, :uom, :string
    add_column :client_sku_masters, :uom_id, :integer
    add_column :client_sku_masters, :production_cost, :float
  end
end
