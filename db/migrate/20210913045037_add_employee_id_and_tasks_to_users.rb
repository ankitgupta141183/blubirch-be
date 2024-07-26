class AddEmployeeIdAndTasksToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :employee_id, :string
    add_column :users, :tasks, :jsonb, default: {}
    add_column :users, :onboarded_by, :string
    add_column :users, :status, :string
  end
end