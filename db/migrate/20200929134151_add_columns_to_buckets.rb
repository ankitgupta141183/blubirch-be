class AddColumnsToBuckets < ActiveRecord::Migration[6.0]
  def change
    change_column_default :vendor_returns, :is_active, true
    add_column :replacements, :is_active, :boolean, default: true
    add_column :insurances, :is_active, :boolean, default: true
    add_column :repairs, :is_active, :boolean, default: true
  end
end
