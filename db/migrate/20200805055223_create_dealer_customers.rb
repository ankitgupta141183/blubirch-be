class CreateDealerCustomers < ActiveRecord::Migration[6.0]
  def change
    create_table :dealer_customers do |t|
      t.string :name
      t.string :phone_number
      t.string :email
      t.integer :state_id
      t.integer :state
      t.integer :city_id
      t.string :city
      t.integer :country_id
      t.string :country
      t.string :pincode
      t.string :gst_number
      t.string :code
      t.integer :dealer_id
      t.string :dealer_code
      t.datetime :deleted_at
      t.timestamps
    end
  end
end
