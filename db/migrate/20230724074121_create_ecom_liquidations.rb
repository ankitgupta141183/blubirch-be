class CreateEcomLiquidations < ActiveRecord::Migration[6.0]
  def change
    create_table :ecom_liquidations do |t|
      t.string :tag_number
      t.string :inventory_sku
      t.text :inventory_description
      t.references :inventory
      t.references :user
      t.string :grade
      t.string :brand
      t.references :liquidation
      t.string :platform 
      t.string :category_l1
      t.string :category_l2
      t.string :category_l3
      t.decimal :quantity
      t.integer :discount
      t.decimal :amount
      t.datetime :start_time
      t.datetime :end_time
      t.integer :external_request_id
      t.integer :external_product_id
      t.string :status 
      t.integer :publish_status
      t.jsonb :details
      t.timestamps
    end
  end
end
