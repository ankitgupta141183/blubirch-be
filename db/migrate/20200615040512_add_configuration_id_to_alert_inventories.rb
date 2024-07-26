class AddConfigurationIdToAlertInventories < ActiveRecord::Migration[6.0]
  def change
    add_reference :alert_inventories, :alert_configuration, foreign_key: true
  	add_column :alert_inventories, :deleted_at, :datetime
  end
end
