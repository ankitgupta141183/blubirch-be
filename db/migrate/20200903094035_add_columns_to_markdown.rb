class AddColumnsToMarkdown < ActiveRecord::Migration[6.0]
  def change
    add_column :markdowns, :client_id, :integer
    add_column :markdowns, :client_tag_number, :string
    add_column :markdowns, :serial_number, :string
    add_column :markdowns, :toat_number, :string
    add_column :markdowns, :aisle_location, :string
    add_column :markdowns, :item_price, :float
    add_column :markdowns, :serial_number_2, :string
  end
end
