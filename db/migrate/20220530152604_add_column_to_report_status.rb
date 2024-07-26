class AddColumnToReportStatus < ActiveRecord::Migration[6.0]
  def change
    add_column :report_statuses, :latest, :boolean, default: false
    add_column :report_statuses, :report_for, :string
  end
end
