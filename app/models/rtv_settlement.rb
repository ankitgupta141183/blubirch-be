class RtvSettlement < ApplicationRecord
	acts_as_paranoid
  has_many :rtv_attachments, as: :attachable 
  mount_uploader :attachment_file,  ConsignmentFileUploader
end
