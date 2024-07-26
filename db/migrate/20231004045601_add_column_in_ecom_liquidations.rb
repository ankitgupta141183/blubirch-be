class AddColumnInEcomLiquidations < ActiveRecord::Migration[6.0]
  def change
    add_column :ecom_liquidations, :platform_response, :text
  end
end
