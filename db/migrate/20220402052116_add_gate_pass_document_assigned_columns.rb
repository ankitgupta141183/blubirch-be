class AddGatePassDocumentAssignedColumns < ActiveRecord::Migration[6.0]
  def change
    add_column :gate_passes, :assigned_user_id, :integer
    add_column :gate_passes, :assigned_at, :datetime
    add_column :gate_passes, :assigned_status, :boolean, default: false    
  end
end
