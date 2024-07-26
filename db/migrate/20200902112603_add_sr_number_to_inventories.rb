class AddSrNumberToInventories < ActiveRecord::Migration[6.0]
  def change
    add_column :inventories, :sr_number, :string
    add_column :inventories, :serial_number_2, :string
  end
end
