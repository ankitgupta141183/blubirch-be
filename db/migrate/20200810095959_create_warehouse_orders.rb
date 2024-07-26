class CreateWarehouseOrders < ActiveRecord::Migration[6.0]
  def change
    create_table :warehouse_orders do |t|
      t.integer :orderable_id
      t.string :orderable_type
      t.integer :distribution_center_id
      t.integer :client_id
      t.integer :status_id
      t.integer :warehouse_gatepass_id
      t.integer :warehouse_consignment_id
      t.string :reference_number
      t.integer :total_quantity
      t.string :gatepass_number
      t.string :outward_invoice_number
      t.jsonb :details
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :warehouse_orders, :distribution_center_id
    add_index :warehouse_orders, :client_id
    add_index :warehouse_orders, :warehouse_gatepass_id 
    add_index :warehouse_orders, :warehouse_consignment_id 
  end
end
