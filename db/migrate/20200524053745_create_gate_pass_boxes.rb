class CreateGatePassBoxes < ActiveRecord::Migration[6.0]
  def change
    create_table :gate_pass_boxes do |t|
      t.integer :gate_pass_id
      t.integer :packaging_box_id
      t.integer :user_id
      t.timestamps
    end
    add_index :gate_pass_boxes, :gate_pass_id
    add_index :gate_pass_boxes, :packaging_box_id
    add_index :gate_pass_boxes, :user_id
  end  
end
