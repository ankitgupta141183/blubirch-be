class AddRequestToGradeColumnToRepair < ActiveRecord::Migration[6.0]
  def change
    add_column :repairs, :request_to_grade, :boolean, default: false
  end
end
