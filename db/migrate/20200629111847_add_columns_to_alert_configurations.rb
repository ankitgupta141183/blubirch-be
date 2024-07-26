class AddColumnsToAlertConfigurations < ActiveRecord::Migration[6.0]
  def change
    add_column :alert_configurations, :disposition, :string
    add_column :alert_configurations, :status, :string
    add_reference :alert_configurations, :distribution_center , index: true 
  end
end
