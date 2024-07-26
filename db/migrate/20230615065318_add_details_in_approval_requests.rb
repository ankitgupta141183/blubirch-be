class AddDetailsInApprovalRequests < ActiveRecord::Migration[6.0]
  def change
    add_column :approval_requests, :details, :jsonb
  end
end
