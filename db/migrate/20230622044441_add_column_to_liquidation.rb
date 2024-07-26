class AddColumnToLiquidation < ActiveRecord::Migration[6.0]
  def change
    add_column :liquidations, :assigned_disposition, :string
    add_column :liquidations, :assigned_id, :integer
  end
end
