class CreateDealerOrders < ActiveRecord::Migration[6.0]
  def change
    create_table :dealer_orders do |t|
      t.string :dealer_code
      t.string :dealer_name
      t.string :dealer_city
      t.string :dealer_state
      t.string :dealer_country
      t.string :dealer_pincode
      t.integer :client_id
      t.integer :dealer_id
      t.string :dealer_phone_number
      t.string :dealer_email
      t.integer :quantity
      t.float :total_amount
      t.float :discount_percentage
      t.float :discount_amount
      t.float :order_amount
      t.string :order_number
      t.integer :status_id
      t.string :status
      t.integer :approved_quantity
      t.integer :rejected_quantity
      t.float :approved_amount
      t.float :rejected_amount
      t.float :approved_discount_percentage
      t.float :approved_discount_amount
      t.text :remarks
      t.integer :user_id
      t.string :invoice_number
      t.string :invoice_attachement_file_type
      t.string :invoice_attachement_file
      t.integer :invoice_user_id
      t.integer :box_count
      t.integer :received_box_count
      t.integer :not_received_box_count
      t.integer :excess_box_count
      t.integer :sent_inventory_count
      t.integer :received_inventory_count
      t.integer :excess_inventory_count
      t.integer :not_received_inventory_count
      t.integer :dispatch_count
      t.float :tax_percentage
      t.float :tax_amount
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :dealer_orders, :client_id
    add_index :dealer_orders, :dealer_id
    add_index :dealer_orders, :status_id
    add_index :dealer_orders, :user_id
    add_index :dealer_orders, :invoice_user_id
  end
end
