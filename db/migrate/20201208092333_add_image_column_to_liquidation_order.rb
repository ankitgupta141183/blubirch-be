class AddImageColumnToLiquidationOrder < ActiveRecord::Migration[6.0]
  def change
    add_column :liquidation_orders, :lot_image_urls, :text, array: true, default: []
    add_column :liquidation_orders, :remarks, :text
  end
end
