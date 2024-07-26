class CreateBids < ActiveRecord::Migration[6.0]
  def change
    create_table :bids do |t|
      t.integer :liquidation_order_id
      t.float :bid_price
      t.string :bid_status
      t.string :user_name
      t.string :user_email
      t.string :user_mobile
      t.string :client_ip
      t.boolean :is_active
      t.timestamps
    end
  end
end