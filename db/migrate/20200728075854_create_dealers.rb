class CreateDealers < ActiveRecord::Migration[6.0]
  def change
    create_table :dealers do |t|
      t.string :dealer_code
      t.string :company_name
      t.string :first_name
      t.string :last_name
      t.string :email
      t.string :phone_number
      t.integer :dealer_type_id
      t.string :dealer_type
      t.string :gst_number
      t.string :pan_number
      t.string :cin_number
      t.string :account_number
      t.string :bank_name
      t.string :ifsc_code
      t.string :address_1
      t.string :address_2
      t.integer :city_id
      t.string :city
      t.integer :state_id
      t.string :state
      t.integer :country_id
      t.string :country
      t.string :pincode
      t.integer :status_id
      t.string :status
      t.string :ancestry
      t.integer :onboarded_user_id
      t.string :onboarder_by
      t.integer :onboarded_employee_code
      t.string :onboarded_employee_phone_no
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
