class CreateReportStatuses < ActiveRecord::Migration[6.0]
  def change
    create_table :report_statuses do |t|
      t.references :user
      t.references :distribution_center
      t.string :status
      t.string :report_type
      t.jsonb :details
      t.datetime :deleted_at
      t.timestamps
    end
  end
end
