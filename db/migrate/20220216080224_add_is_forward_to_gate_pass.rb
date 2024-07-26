class AddIsForwardToGatePass < ActiveRecord::Migration[6.0]
  def change
    add_column :gate_passes , :is_forward, :boolean, default: true
  end
end
