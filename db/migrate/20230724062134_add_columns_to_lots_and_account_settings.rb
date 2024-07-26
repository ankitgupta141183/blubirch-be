class AddColumnsToLotsAndAccountSettings < ActiveRecord::Migration[6.0]
  def change
    #! Account Setting columns
    add_column :account_settings, :ext_b2c_platforms, :jsonb
  end
end
