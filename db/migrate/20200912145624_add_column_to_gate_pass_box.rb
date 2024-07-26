class AddColumnToGatePassBox < ActiveRecord::Migration[6.0]
  def change
    add_column :gate_pass_boxes, :deleted_at, :datetime
  end
end
