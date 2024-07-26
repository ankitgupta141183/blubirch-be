class AddColumnToLookupValues < ActiveRecord::Migration[6.0]
  def change
    add_column :lookup_values, :min_value, :integer
    add_column :lookup_values, :max_value, :integer
    add_column :lookup_values, :is_mandatory, :boolean, default: false
  end
end
