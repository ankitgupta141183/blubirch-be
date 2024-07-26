class AddDeliveryReferenceNumberInWarehouseOrders < ActiveRecord::Migration[6.0]
  def change
    add_column :warehouse_orders, :delivery_reference_number, :string
  end
end
