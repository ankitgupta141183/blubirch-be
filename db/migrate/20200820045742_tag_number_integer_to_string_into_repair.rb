class TagNumberIntegerToStringIntoRepair < ActiveRecord::Migration[6.0]
  def up
    change_column :repairs, :tag_number, :string
  end

  def down
    change_column :repairs, :tag_number, :integer
  end
end
