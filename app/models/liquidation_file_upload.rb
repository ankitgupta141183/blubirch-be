class LiquidationFileUpload < ApplicationRecord
	acts_as_paranoid
	mount_uploader :liquidation_file,  FileUploader

	belongs_to :user
	belongs_to :client, optional: true

	after_create :upload_file

	def upload_file
		LiquidationFileUploadWorker.perform_async(id)
	end

end
