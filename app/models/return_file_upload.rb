class ReturnFileUpload < ApplicationRecord

	acts_as_paranoid
	mount_uploader :return_file,  FileUploader

	belongs_to :user
	belongs_to :client, optional: true

	after_create :upload_file

	def upload_file
		ReturnFileUploadWorker.perform_in(1.minutes, id)
	end

end
