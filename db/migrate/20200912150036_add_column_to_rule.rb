class AddColumnToRule < ActiveRecord::Migration[6.0]
  def change
    add_column :rules, :deleted_at, :datetime
  end
end
