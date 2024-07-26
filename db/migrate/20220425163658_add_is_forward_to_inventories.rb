class AddIsForwardToInventories < ActiveRecord::Migration[6.0]
  def change
    add_column :inventories, :is_forward, :boolean, default: true
  end
end
