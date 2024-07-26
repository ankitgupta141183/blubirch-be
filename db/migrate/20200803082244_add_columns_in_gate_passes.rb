class AddColumnsInGatePasses < ActiveRecord::Migration[6.0]
  def change
    add_column :gate_passes, :client_gatepass_number, :string
    add_column :gate_passes, :dispatch_date, :datetime
    add_column :gate_passes, :sr_number, :string
    add_column :gate_passes, :source_id, :integer
    add_column :gate_passes, :destination_id, :integer
    add_column :gate_passes, :source_code, :string
    add_column :gate_passes, :destination_code, :string
    add_column :gate_passes, :source_address, :string
    add_column :gate_passes, :source_city, :string
    add_column :gate_passes, :source_state, :string
    add_column :gate_passes, :source_country, :string
    add_column :gate_passes, :source_pincode, :string
    add_column :gate_passes, :destination_address, :string
    add_column :gate_passes, :destination_city, :string
    add_column :gate_passes, :destination_state, :string
    add_column :gate_passes, :destination_country, :string
    add_column :gate_passes, :destination_pincode, :string
    add_column :gate_passes, :total_quantity, :integer
    add_column :gate_passes, :status, :string
  end
end