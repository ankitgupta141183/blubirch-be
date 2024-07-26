class AddColumnToDispositionRule < ActiveRecord::Migration[6.0]
  def change
    add_column :disposition_rules, :deleted_at, :datetime
  end
end
