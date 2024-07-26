class AddColumnsToApprovalRequests < ActiveRecord::Migration[6.0]
  def change
    add_column :approval_requests, :rule_field, :integer, :default => ApprovalRequest.rule_fields["amount"]
    add_column :approval_requests, :approval_rule_type, :integer, :default => ApprovalRequest.approval_rule_types["insurance"]
    add_column :approval_requests, :value, :float
  end
end
