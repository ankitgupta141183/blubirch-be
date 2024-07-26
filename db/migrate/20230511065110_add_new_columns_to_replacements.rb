class AddNewColumnsToReplacements < ActiveRecord::Migration[6.0]
  def change
    add_column :replacements, :approval_code, :string
    add_column :replacements, :is_confirmed, :boolean, :default => false
  end
end
