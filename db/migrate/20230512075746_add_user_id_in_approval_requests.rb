class AddUserIdInApprovalRequests < ActiveRecord::Migration[6.0]
  def change
    add_column :approval_requests, :user_id, :integer
  end
end
