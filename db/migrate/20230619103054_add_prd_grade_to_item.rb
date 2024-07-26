class AddPrdGradeToItem < ActiveRecord::Migration[6.0]
  def change
    add_column :items, :prd_grade, :string
  end
end
