class CreateUserAccountSettings < ActiveRecord::Migration[6.0]
  def change
    create_table :user_account_settings do |t|
      t.references :user, index: true
      t.string :bidding_method
      t.string :organization_name

      t.timestamps
    end
  end
end
