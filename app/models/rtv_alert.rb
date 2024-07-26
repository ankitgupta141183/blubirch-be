class RtvAlert < ApplicationRecord
	acts_as_paranoid
  mount_uploader :attachment_file,  ConsignmentFileUploader
  has_many :rtv_attachments, as: :attachable
end
