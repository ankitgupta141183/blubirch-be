class AddColumnToEwasteOrder < ActiveRecord::Migration[6.0]
  def change
    add_column :e_waste_orders, :lot_name, :string
    add_column :e_waste_orders, :lot_desc, :string
    add_column :e_waste_orders, :mrp, :float
    add_column :e_waste_orders, :end_date, :datetime 
    add_column :e_waste_orders, :status, :string
    add_column :e_waste_orders, :status_id, :integer

    add_column :e_waste_orders, :winner_code, :string
    add_column :e_waste_orders, :winner_amount, :float
    add_column :e_waste_orders, :payment_status, :string
    add_column :e_waste_orders, :payment_status_id, :integer
    add_column :e_waste_orders, :amount_received, :float
    add_column :e_waste_orders, :dispatch_ready, :boolean
    add_column :e_waste_orders, :quantity, :integer
  end
end
