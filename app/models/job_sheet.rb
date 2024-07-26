class JobSheet < ApplicationRecord
	acts_as_paranoid
  belongs_to :repair, optional: true
  has_many :job_sheet_parts
  belongs_to :grade, class_name: "LookupValue", foreign_key: :grade_id, optional: true
  
end
