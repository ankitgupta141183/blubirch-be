class ApprovalUser < ApplicationRecord
  belongs_to :approval_configuration
  belongs_to :user
end
