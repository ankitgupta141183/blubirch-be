class AddColumnRepublishStatusToLiquidationOrder < ActiveRecord::Migration[6.0]
  def change
    add_column :liquidation_orders, :republish_status, :integer, default: nil
  end
end
