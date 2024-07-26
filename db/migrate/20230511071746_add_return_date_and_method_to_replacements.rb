class AddReturnDateAndMethodToReplacements < ActiveRecord::Migration[6.0]
  def change
    add_column :replacements, :return_method, :integer
    add_column :replacements, :return_date, :date
  end
end
