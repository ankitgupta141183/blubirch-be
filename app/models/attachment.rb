class Attachment < ApplicationRecord
	acts_as_paranoid
  mount_uploader :file ,  ConsignmentFileUploader
  belongs_to :attachable, polymorphic: true
end
