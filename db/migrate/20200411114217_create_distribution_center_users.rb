class CreateDistributionCenterUsers < ActiveRecord::Migration[6.0]
  def change
    create_table :distribution_center_users do |t|
     t.integer :user_id
     t.integer :distribution_center_id
     t.datetime :deleted_at
     t.timestamps
   	end
    add_index :distribution_center_users, :user_id
    add_index :distribution_center_users, :distribution_center_id
  end
end
