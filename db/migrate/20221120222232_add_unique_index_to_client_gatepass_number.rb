class AddUniqueIndexToClientGatepassNumber < ActiveRecord::Migration[6.0]
  def change
    remove_index :gate_passes, :client_gatepass_number
    remove_index :outbound_documents, :client_gatepass_number
    add_index :gate_passes, :client_gatepass_number, unique: true
    add_index :outbound_documents, :client_gatepass_number, unique: true
  end
end
