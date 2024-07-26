class AddGradeAsIndexInJobSheet < ActiveRecord::Migration[6.0]
  def change
  	add_index :job_sheets, :grade_id
  end
end
