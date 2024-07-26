class AddReasonAndShortQuantityToInventories < ActiveRecord::Migration[6.0]
  def change
    add_column :inventories, :short_reason, :string
    add_column :inventories, :short_quantity, :integer
  end
end
