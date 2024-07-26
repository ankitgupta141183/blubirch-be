class CreateClientPriceMasters < ActiveRecord::Migration[6.0]
  def change
    create_table :client_price_masters do |t|
      t.integer :client_sku_master_id
      t.integer :client_id
      t.string :sku_code
      t.integer :sku_ean_id
      t.string :ean
      t.float :mrp
      t.float :map
      t.float :asp
      t.float :purchase_price
      t.float :sales_price
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :client_price_masters, :client_sku_master_id
    add_index :client_price_masters, :client_id
    add_index :client_price_masters, :sku_ean_id
    add_index :client_price_masters, :ean
    add_index :client_price_masters, :sku_code

  end
end
