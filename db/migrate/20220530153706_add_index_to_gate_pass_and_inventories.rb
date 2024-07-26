class AddIndexToGatePassAndInventories < ActiveRecord::Migration[6.0]
  def change
    add_index :gate_passes, :client_gatepass_number
    add_index :gate_passes, :assigned_user_id
    add_index :inventories, :client_category_id
  end
end
