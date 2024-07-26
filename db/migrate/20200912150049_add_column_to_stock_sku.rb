class AddColumnToStockSku < ActiveRecord::Migration[6.0]
  def change
    add_column :stock_skus, :deleted_at, :datetime
  end
end
