class ConsignmentFile < ApplicationRecord
	acts_as_paranoid
  mount_uploader :consignment_file,  ConsignmentFileUploader
  belongs_to :consignment

end
