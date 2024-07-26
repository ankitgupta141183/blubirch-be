class CreateOrders < ActiveRecord::Migration[6.0]
  def change
    create_table :orders do |t|
    	t.integer :client_id
    	t.integer :user_id
    	t.integer :order_type_id
    	t.string :order_number
    	t.text :from_address
    	t.text :to_address
    	t.datetime :deleted_at
      t.timestamps
    end
    add_index :orders, :client_id
    add_index :orders, :user_id
    add_index :orders, :order_type_id
  end
end
