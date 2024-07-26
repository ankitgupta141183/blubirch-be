class AddColumnToReplacementTable < ActiveRecord::Migration[6.0]
  def change
    add_column :replacements, :resolution_date, :datetime
  end
end
