class AddDetailsToLiquidationHistories < ActiveRecord::Migration[6.0]
  def change
    add_column :liquidation_histories, :details, :jsonb, default: {}
  end
end
