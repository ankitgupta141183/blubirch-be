class AddSaleableReferenceToSaleOrder < ActiveRecord::Migration[6.0]
  def change
    add_reference :sale_orders, :saleable, null: false, foreign_key: true
  end
end
