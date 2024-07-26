class AddColumnToDealerOrderItem < ActiveRecord::Migration[6.0]
  def change
    add_column :dealer_order_items, :save_status, :boolean
  end
end
