class AddColumnToQcConfiguration < ActiveRecord::Migration[6.0]
  def change
    add_column :qc_configurations, :deleted_at, :datetime
  end
end
