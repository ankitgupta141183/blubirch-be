class ChangeDetailsColumnTypeInDistributionCenterUsers < ActiveRecord::Migration[6.0]
  def change
  	remove_column :distribution_center_users, :details, :jsonb, default: {}
  	add_column :distribution_center_users, :details, :jsonb, array: true, default: []
  end
end
