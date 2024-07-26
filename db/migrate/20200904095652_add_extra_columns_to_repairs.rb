class AddExtraColumnsToRepairs < ActiveRecord::Migration[6.0]
  def change
    add_column :repairs, :client_id, :integer
    add_column :repairs, :client_category_id, :integer
    add_column :repairs, :client_tag_number, :string
    add_column :repairs, :serial_number, :string
    add_column :repairs, :serial_number_2, :string
    add_column :repairs, :toat_number, :string
    add_column :repairs, :aisle_location, :string
    add_column :repairs, :item_price, :float
    add_index :repairs, :client_id
    add_index :repairs, :client_category_id
  end
end