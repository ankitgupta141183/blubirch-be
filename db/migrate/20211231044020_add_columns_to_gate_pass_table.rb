class AddColumnsToGatePassTable < ActiveRecord::Migration[6.0]
  def change
    add_column :gate_passes, :document_type, :string
    add_column :gate_passes, :document_type_id, :integer
    add_column :gate_passes, :vendor_code, :string
    add_column :gate_passes, :vendor_name, :string
    add_column :gate_passes, :recieved_date, :datetime
    add_column :gate_passes, :inwarded_by_user, :integer
  end
end