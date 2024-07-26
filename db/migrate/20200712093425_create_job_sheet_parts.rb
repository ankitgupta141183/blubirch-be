class CreateJobSheetParts < ActiveRecord::Migration[6.0]
  def change
    create_table :job_sheet_parts do |t|

    	t.integer :job_sheet_id
      t.integer :repair_part_id
      t.integer :quantity
      t.float :amount
      t.json :details
      t.boolean :repaired, default: false
      t.boolean :is_active, default: true
      t.datetime :deleted_at
      
      t.timestamps
    end
  end
end
