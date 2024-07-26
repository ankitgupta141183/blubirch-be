class AddColumnFloorPriceToLiquidation < ActiveRecord::Migration[6.0]
  def change
    add_column :liquidations, :floor_price, :float
  end
end
