class AddChangedSkuCodeToItem < ActiveRecord::Migration[6.0]
  def change
    add_column :items, :changed_sku_code, :string
  end
end
