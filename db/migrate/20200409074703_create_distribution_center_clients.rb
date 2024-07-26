class CreateDistributionCenterClients < ActiveRecord::Migration[6.0]
  def change
    create_table :distribution_center_clients do |t|
      t.integer :client_id
      t.integer :distribution_center_id
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :distribution_center_clients, :client_id
    add_index :distribution_center_clients, :distribution_center_id
  end
end
