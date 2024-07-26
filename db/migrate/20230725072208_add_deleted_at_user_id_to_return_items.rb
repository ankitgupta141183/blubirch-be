class AddDeletedAtUserIdToReturnItems < ActiveRecord::Migration[6.0]
  def change
    add_column :return_items, :deleted_at, :datetime
    add_column :return_items, :user_id, :integer
    add_column :return_items, :client_id, :integer
    add_index :return_items, :user_id
    add_index :return_items, :client_id
  end
end
