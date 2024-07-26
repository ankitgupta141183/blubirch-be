class AddTatToAccountSetting < ActiveRecord::Migration[6.0]
  def change
    remove_column :client_configurations, :tat_days, :integer
    add_column :account_settings, :tat_days, :integer
  end
end
