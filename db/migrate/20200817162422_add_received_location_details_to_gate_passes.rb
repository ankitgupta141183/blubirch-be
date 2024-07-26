class AddReceivedLocationDetailsToGatePasses < ActiveRecord::Migration[6.0]
  def change
    add_column :gate_passes, :received_id, :integer
    add_column :gate_passes, :received_code, :integer
    add_column :gate_passes, :received_address, :string
    add_column :gate_passes, :received_city, :string
    add_column :gate_passes, :received_state, :string
    add_column :gate_passes, :received_country, :string
    add_column :gate_passes, :received_pincode, :string
    add_column :gate_passes, :received_time, :datetime
  end
end
