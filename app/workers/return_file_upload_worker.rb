class ReturnFileUploadWorker

	include Sidekiq::Worker

	def perform(return_file_upload_id)

		return_file_upload = ReturnFileUpload.where("id = ?", return_file_upload_id).first
		return_file_upload.update(status: "Import Started")
		
		begin
			ReturnItem.import_file(return_file_upload_id)
		rescue => e
			return_file_upload.status = "Error"
			return_file_upload.remarks = e.to_s
			return_file_upload.save
		end	
		
	end

end
