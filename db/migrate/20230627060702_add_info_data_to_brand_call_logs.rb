class AddInfoDataToBrandCallLogs < ActiveRecord::Migration[6.0]
  def change
    add_column :brand_call_logs, :info_data, :jsonb
  end
end
