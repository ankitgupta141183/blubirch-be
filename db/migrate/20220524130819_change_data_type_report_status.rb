class ChangeDataTypeReportStatus < ActiveRecord::Migration[6.0]
  def change
    remove_column :report_statuses, :distribution_center_id
    add_column :report_statuses, :distribution_center_ids, :text, array: true, default: []
  end
end
