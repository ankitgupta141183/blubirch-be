class AddTagNumberToReturnItems < ActiveRecord::Migration[6.0]
  def change
    add_column :return_items, :tag_number, :string
    add_column :return_items, :irrd_number, :string
    add_column :return_items, :box_number, :string
    
    add_index :return_items, :tag_number
    add_index :return_items, :irrd_number
  end
end
