class AddColumnInApprovalRequest < ActiveRecord::Migration[6.0]
  def change
    add_column :approval_requests, :status, :integer
  end
end
