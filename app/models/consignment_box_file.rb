class ConsignmentBoxFile < ApplicationRecord
	acts_as_paranoid
  mount_uploader :consignment_box_file,  ConsignmentFileUploader
  belongs_to :consignment_box
end
