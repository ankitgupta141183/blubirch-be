class AddColumnBatchNumberToGatePass < ActiveRecord::Migration[6.0]
  def change
    add_column :gate_passes, :batch_number, :string
    add_column :gate_passes, :synced_response, :jsonb
    add_column :gate_passes, :synced_response_received_at, :datetime
  end
end
