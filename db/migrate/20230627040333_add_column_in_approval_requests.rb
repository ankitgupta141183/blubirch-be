class AddColumnInApprovalRequests < ActiveRecord::Migration[6.0]
  def change
    add_column :approval_requests, :exception_response, :text
  end
end
