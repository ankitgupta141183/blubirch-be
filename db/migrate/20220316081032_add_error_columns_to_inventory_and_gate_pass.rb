class AddErrorColumnsToInventoryAndGatePass < ActiveRecord::Migration[6.0]
  def change
    add_column :gate_passes, :is_error_response_received, :boolean, default: false
    add_column :gate_passes, :is_error, :boolean, default: false
    add_column :inventories, :is_error_response_received, :boolean, default: false
    add_column :inventories, :is_error, :boolean, default: false
    add_column :inventories, :error_string, :string
  end
end
