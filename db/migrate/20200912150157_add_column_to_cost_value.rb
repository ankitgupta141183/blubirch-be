class AddColumnToCostValue < ActiveRecord::Migration[6.0]
  def change
    add_column :cost_values, :deleted_at, :datetime
  end
end
