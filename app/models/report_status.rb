class ReportStatus < ApplicationRecord
  acts_as_paranoid
  belongs_to :user, optional: true
  validates :status, inclusion: { in: ["In Process", "Completed", "Halted"] }
  validates :report_type, inclusion: { in: ["inward", "outward", "visiblity"] }
  validates :report_for, inclusion: { in: ["central_admin", "site_admin"] }
end