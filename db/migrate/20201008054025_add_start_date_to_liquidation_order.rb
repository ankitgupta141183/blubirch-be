class AddStartDateToLiquidationOrder < ActiveRecord::Migration[6.0]
  def change
    add_column :liquidation_orders, :start_date, :datetime
  end
end
