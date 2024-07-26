class AddSaleableReferenceToBackOrder < ActiveRecord::Migration[6.0]
  def change
    add_reference :back_orders, :saleable, null: true, foreign_key: true
    add_reference :back_orders, :sale_order, null: true, foreign_key: true
  end
end
