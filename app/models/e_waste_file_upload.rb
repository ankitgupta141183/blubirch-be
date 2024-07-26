class EWasteFileUpload < ApplicationRecord
	mount_uploader :e_waste_file,  FileUploader
	acts_as_paranoid
	belongs_to :user
	belongs_to :client, optional: true

	after_create :upload_file

	def upload_file
		EWasteFileUploadWorker.perform_async(id)
	end
end
