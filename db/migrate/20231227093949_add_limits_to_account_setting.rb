class AddLimitsToAccountSetting < ActiveRecord::Migration[6.0]
  def change
    add_column :account_settings, :criticality_limits, :jsonb
  end
end
