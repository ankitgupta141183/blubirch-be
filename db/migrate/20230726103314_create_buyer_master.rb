class CreateBuyerMaster < ActiveRecord::Migration[6.0]
  def change
    create_table :buyer_masters do |t|
      t.string :username
      t.string :email
      t.string :first_name
      t.string :last_name
      t.boolean :is_active, default: false
      t.integer :organization_id
      t.string :organization_name

      t.timestamps
    end
  end
end
