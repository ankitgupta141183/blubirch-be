class CreateSkuEans < ActiveRecord::Migration[6.0]
  def change
    create_table :sku_eans do |t|
      t.integer :client_sku_master_id
      t.string :ean
      t.timestamps
    end
    add_index :sku_eans, :client_sku_master_id
  end
end