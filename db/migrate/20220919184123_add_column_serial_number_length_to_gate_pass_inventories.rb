class AddColumnSerialNumberLengthToGatePassInventories < ActiveRecord::Migration[6.0]
  def change
    add_column :gate_pass_inventories, :serial_number_length, :integer, default: 0
    add_column :outbound_document_articles, :serial_number_length, :integer, default: 0
  end
end
