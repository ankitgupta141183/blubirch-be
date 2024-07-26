class CreateEcomPurchaseHistories < ActiveRecord::Migration[6.0]
  def change
    create_table :ecom_purchase_histories do |t|
      t.integer :status 
      t.string :order_number 
      t.integer :quantity 
      t.string :username
      t.text :address_1
      t.text :address_2
      t.string :city
      t.string :state
      t.decimal :amount 
      t.references :ecom_liquidation
      t.timestamps
    end
  end
end
