class AddColumnsToReplacements < ActiveRecord::Migration[6.0]
  def change
    add_column :replacements, :client_id, :integer
    add_column :replacements, :client_tag_number, :string
    add_column :replacements, :serial_number, :string
    add_column :replacements, :toat_number, :string
    add_column :replacements, :aisle_location, :string
    remove_column :replacements, :sr_number1, :string
    remove_column :replacements, :sr_number2, :string
    add_column :replacements, :sr_number, :string
    add_column :replacements, :serial_number_2, :string
  end
end
