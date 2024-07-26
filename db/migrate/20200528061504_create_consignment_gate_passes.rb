class CreateConsignmentGatePasses < ActiveRecord::Migration[6.0]
  def change
    create_table :consignment_gate_passes do |t|

      t.integer :consignment_id
      t.integer :gate_pass_id
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :consignment_gate_passes, :consignment_id
    add_index :consignment_gate_passes, :gate_pass_id
  end
end
