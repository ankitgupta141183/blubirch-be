class CreateConsignmentBoxes < ActiveRecord::Migration[6.0]
  def change
    create_table :consignment_boxes do |t|
      t.integer :consignment_gate_pass_id
      t.integer :distribution_center_id
      t.integer :box_count
      t.integer :received_box_count
      t.datetime :delivery_date
      t.integer :logistics_partner_id
      t.datetime :deleted_at
      t.timestamps
    end

    add_index :consignment_boxes, :consignment_gate_pass_id
    add_index :consignment_boxes, :distribution_center_id
    add_index :consignment_boxes, :logistics_partner_id

  end
end
