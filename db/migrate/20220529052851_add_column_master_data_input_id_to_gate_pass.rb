class AddColumnMasterDataInputIdToGatePass < ActiveRecord::Migration[6.0]
  def change
    add_column :gate_passes, :master_data_input_id, :integer
    add_column :master_data_inputs, :is_response_pushed, :boolean, default: false
    add_index :gate_passes, :master_data_input_id
  end
end
