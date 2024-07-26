class CreateAccountSettings < ActiveRecord::Migration[6.0]
  def change
    create_table :account_settings do |t|
      t.integer :benchmark_price
      t.string :username
      t.integer :bidding_method
      t.references :user, index: true
      t.timestamps
    end
  end
end
