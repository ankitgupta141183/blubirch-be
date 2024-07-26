class BoxReceiptAcknowledgement < ApplicationRecord

  mount_uploader :attachment_file ,  ConsignmentFileUploader
  belongs_to :attachmentable, polymorphic: true, optional: true

  def attachment_name
    File.basename(self.attachment_file_url) || " "
  end
end
