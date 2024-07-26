class CreateWarehouseGatePasses < ActiveRecord::Migration[6.0]
  def change
    create_table :warehouse_gate_passes do |t|
      t.integer :distribution_center_id
      t.integer :user_id
      t.string :gate_pass_number
      t.integer :status_id
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :warehouse_gate_passes, :distribution_center_id
    add_index :warehouse_gate_passes, :user_id
  end
end
