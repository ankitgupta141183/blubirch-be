class ApprovalConfiguration < ApplicationRecord
  enum approval_config_type: {
    single: "single", multi: "multi"
  }

  enum approval_flow: {
    parallel: "parallel", hierarchal: "hierarchal"
  }

  has_many :approval_users, dependent: :destroy
  has_many :approval_requests, dependent: :destroy

  after_commit :sync_to_rule_engine

  accepts_nested_attributes_for :approval_users

  #& Get the approval configuration record
  #? config_type: [single, multi] && flow: [parallel, hierarchal]
  #^ ApprovalConfiguration.approval_configuration(object_name: 'Insurance')
  def self.get_record(object_name:)
    ApprovalConfiguration.where(approval_name: object_name).last
  end

  private

  def sync_to_rule_engine
    Notification::ApprovalService.new(self).call
  end
end
