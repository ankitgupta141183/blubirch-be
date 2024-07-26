class ReplacementAttachment < ApplicationRecord
    acts_as_paranoid
  mount_uploader :attachment_file ,  ConsignmentFileUploader
  belongs_to :attachable, polymorphic: true

  def attachment_name
    File.basename(self.attachment_file_url) || " "
  end
end
