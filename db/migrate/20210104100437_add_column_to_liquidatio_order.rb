class AddColumnToLiquidatioOrder < ActiveRecord::Migration[6.0]
  def change
    add_column :liquidation_orders, :details, :json, default: {}
  end
end
