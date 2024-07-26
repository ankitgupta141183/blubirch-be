class AddColumnsToEcomPurchaseHistories < ActiveRecord::Migration[6.0]
  def change
    add_column :ecom_purchase_histories, :publish_price, :float, :default => 0.0
    add_column :ecom_purchase_histories, :discount_price, :float, :default => 0.0
    add_column :ecom_purchase_histories, :delivery_charges, :float, :default => 0.0
  end
end
