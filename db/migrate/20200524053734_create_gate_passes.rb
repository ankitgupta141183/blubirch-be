class CreateGatePasses < ActiveRecord::Migration[6.0]
  def change
    create_table :gate_passes do |t|
      t.integer :distribution_center_id
      t.integer :client_id
      t.integer :user_id
      t.integer :status_id
      t.string :gatepass_number
      t.timestamps
    end
    add_index :gate_passes, :distribution_center_id
    add_index :gate_passes, :client_id
    add_index :gate_passes, :user_id
    add_index :gate_passes, :status_id
  end
end
