class CreatePaymentHistories < ActiveRecord::Migration[6.0]
  #payable_type
  #payable_id
  #amount 
  #paid_user
  #payment_date 
  #user_id
  def change
    create_table :payment_histories do |t|
      t.string :payable_type
      t.integer :payable_id
      t.float :amount 
      t.string :paid_user
      t.date :payment_date 
      t.references :user
      t.timestamps
    end
  end
end
