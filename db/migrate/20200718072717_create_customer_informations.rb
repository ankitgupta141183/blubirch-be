class CreateCustomerInformations < ActiveRecord::Migration[6.0]
  def change
    create_table :customer_informations do |t|
      t.string :phone_number
      t.string :email_id
      t.string :name
      t.string :code
      t.string :location
      t.string :gst
      t.string :customer_type

      t.timestamps
    end
  end
end
