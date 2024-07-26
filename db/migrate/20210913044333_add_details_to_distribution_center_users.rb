class AddDetailsToDistributionCenterUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :distribution_center_users, :details, :jsonb, default: {}
  end
end
