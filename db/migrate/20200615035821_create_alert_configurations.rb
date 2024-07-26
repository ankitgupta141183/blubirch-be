class CreateAlertConfigurations < ActiveRecord::Migration[6.0]
  def change
    create_table :alert_configurations do |t|
      t.integer :alert_type_id
      t.jsonb :details
      t.datetime :deleted_at
      t.timestamps
    end
  end
end