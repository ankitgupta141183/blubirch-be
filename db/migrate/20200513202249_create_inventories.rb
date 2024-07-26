class CreateInventories < ActiveRecord::Migration[6.0]
  def change
    create_table :inventories do |t|
    	t.integer :distribution_center_id
    	t.integer :client_id
    	t.integer :user_id
      t.string :tag_number
    	t.jsonb :details
    	t.datetime :deleted_at
      t.timestamps
    end
    add_index :inventories, :distribution_center_id
    add_index :inventories, :client_id
    add_index :inventories, :user_id
  end
end
