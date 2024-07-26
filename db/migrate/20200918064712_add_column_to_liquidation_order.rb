class AddColumnToLiquidationOrder < ActiveRecord::Migration[6.0]
  def change
    add_column :liquidation_orders, :lot_name, :string
    add_column :liquidation_orders, :lot_desc, :string
    add_column :liquidation_orders, :mrp, :float
    add_column :liquidation_orders, :end_date, :datetime 
    add_column :liquidation_orders, :status, :string
    add_column :liquidation_orders, :status_id, :integer

    add_column :liquidation_orders, :winner_code, :string
    add_column :liquidation_orders, :winner_amount, :float
    add_column :liquidation_orders, :payment_status, :string
    add_column :liquidation_orders, :payment_status_id, :integer
    add_column :liquidation_orders, :amount_received, :float
    add_column :liquidation_orders, :dispatch_ready, :boolean    
  end
end
