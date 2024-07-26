class CreateStockSkus < ActiveRecord::Migration[6.0]
  def change
    create_table :stock_skus do |t|
      t.string :sku_code
      t.integer :quantity
      t.string :item_name
      t.string :category_name
      t.float :mrp
      t.float :discount_percentage
      t.float :discount_price
      t.integer :gst
      t.string :image_url
      t.integer :last_30_days_quantity

      t.timestamps
    end
  end
end
