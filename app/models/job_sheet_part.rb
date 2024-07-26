class JobSheetPart < ApplicationRecord
	acts_as_paranoid
  belongs_to :job_sheet, optional: true
  belongs_to :repair_part, optional: true

end
