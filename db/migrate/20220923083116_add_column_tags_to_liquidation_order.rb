class AddColumnTagsToLiquidationOrder < ActiveRecord::Migration[6.0]
  def change
    add_column :liquidation_orders, :tags, :string, array: true, default: []
  end
end
