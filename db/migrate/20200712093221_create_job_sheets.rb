class CreateJobSheets < ActiveRecord::Migration[6.0]
  def change
    create_table :job_sheets do |t|

      t.integer :repair_id
      t.integer :grade_id
      t.boolean :is_active, default: true
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
