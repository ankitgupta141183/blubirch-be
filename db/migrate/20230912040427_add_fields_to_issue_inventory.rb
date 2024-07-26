class AddFieldsToIssueInventory < ActiveRecord::Migration[6.0]
  def change
    add_column :issue_inventories, :current_status, :integer
    add_column :issue_inventories, :details, :jsonb
    add_column :issue_inventories, :deleted_at, :datetime
  end
end
