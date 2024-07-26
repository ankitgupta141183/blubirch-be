class MarkdownAttachment < ApplicationRecord
	acts_as_paranoid
	mount_uploader :attachment_file ,  ConsignmentFileUploader
  belongs_to :attachable, polymorphic: true
end
