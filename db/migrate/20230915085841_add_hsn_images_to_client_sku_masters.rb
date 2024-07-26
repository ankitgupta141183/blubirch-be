class AddHsnImagesToClientSkuMasters < ActiveRecord::Migration[6.0]
  def change
    add_column :client_sku_masters, :hsn_code , :string
    add_column :client_sku_masters, :sku_type , :string
    add_column :client_sku_masters, :images , :jsonb, default: []
    add_index :client_sku_masters, :images, using: :gin
  end
end

