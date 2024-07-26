class AddNewColumnsToRepairTable < ActiveRecord::Migration[6.0]
  def change
    add_column :repairs, :repair_quote_percentage, :float
    add_column :repairs, :expected_revised_grade, :integer
    add_column :repairs, :repair_type, :integer
    add_column :repairs, :repair_status, :integer
    add_column :repairs, :tab_status, :integer
  end
end
