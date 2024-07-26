class AddColumnsInInventories < ActiveRecord::Migration[6.0]
  def change
    add_column :inventories, :gate_pass_id, :integer
    add_column :inventories, :sku_code, :string
    add_column :inventories, :item_description, :string
    add_column :inventories, :quantity, :integer
    add_column :inventories, :client_tag_number, :string
    add_column :inventories, :disposition, :string
    add_column :inventories, :grade, :string
    add_column :inventories, :serial_number, :string
    add_column :inventories, :toat_number, :string
    add_column :inventories, :return_reason, :string
    add_column :inventories, :aisle_location, :string
    add_column :inventories, :item_price, :float
    add_index :inventories, :gate_pass_id
  end
end