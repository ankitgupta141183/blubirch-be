class AddRejectColumnInApprovalRequest < ActiveRecord::Migration[6.0]
  def change
    add_column :approval_requests, :reject_hash, :jsonb
    add_column :approval_requests, :rejected_on, :datetime
  end
end
