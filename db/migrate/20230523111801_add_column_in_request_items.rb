class AddColumnInRequestItems < ActiveRecord::Migration[6.0]
  def change
    add_column :request_items, :warehouse_order_item_id, :integer
  end
end
