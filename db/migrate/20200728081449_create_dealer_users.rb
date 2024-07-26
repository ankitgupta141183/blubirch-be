class CreateDealerUsers < ActiveRecord::Migration[6.0]
  def change
    create_table :dealer_users do |t|
      t.integer :user_id
      t.integer :dealer_id
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :dealer_users, :user_id
    add_index :dealer_users, :dealer_id
  end
end
