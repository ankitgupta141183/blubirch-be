class AddIndexForUniqTagNumber < ActiveRecord::Migration[6.0]
  def change
    add_index :inventories, :tag_number, unique: true
  end
end
