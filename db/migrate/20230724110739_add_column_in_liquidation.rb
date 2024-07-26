class AddColumnInLiquidation < ActiveRecord::Migration[6.0]
  def change
    add_column :liquidations, :b2c_publish_status, :integer
  end
end
