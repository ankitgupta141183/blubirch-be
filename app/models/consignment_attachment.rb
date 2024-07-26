class ConsignmentAttachment < ApplicationRecord
  acts_as_paranoid
  belongs_to :consignment_information
  mount_uploader :attachment_file, ConsignmentFileUploader
  
end
