class AddColumnDeliveryTimelineToLiquidationOrder < ActiveRecord::Migration[6.0]
  def change
    add_column :liquidation_orders, :delivery_timeline, :integer
    add_column :liquidation_orders, :additional_info, :text
  end
end
