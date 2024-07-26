class AddTatToClientConfiguration < ActiveRecord::Migration[6.0]
  def change
    add_column :client_configurations, :tat_days, :integer
  end
end
