class AddColumnOnLableToClientSkuMasters < ActiveRecord::Migration[6.0]
  def change
    add_column :client_sku_masters, :own_label, :boolean, default: true
  end
end
