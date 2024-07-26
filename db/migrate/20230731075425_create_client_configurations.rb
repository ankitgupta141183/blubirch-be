class CreateClientConfigurations < ActiveRecord::Migration[6.0]
  def change
    create_table :client_configurations do |t|
      t.string :key
      t.string :code
      t.string :value
      t.integer :client_id
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :client_configurations, :client_id
    add_index :client_configurations, :code
    add_index :client_configurations, :key
    add_index :client_configurations, :value
  end
end
