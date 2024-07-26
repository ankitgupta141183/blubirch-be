class ClientTestRuleUpload < ApplicationRecord
	belongs_to :client
	mount_uploader :file,  FileUploader
end
