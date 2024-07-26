class EWasteFileUploadWorker

	include Sidekiq::Worker

	def perform(e_waste_file_upload_id)
		e_waste_file_upload = EWasteFileUpload.where("id = ?", e_waste_file_upload_id).first
		e_waste_file_upload.update(status: "Import Started")
		begin
			EWaste.import_lots(e_waste_file_upload_id)
		rescue => e
			e_waste_file_upload.status = "Error"
			e_waste_file_upload.remarks = e.to_s
			e_waste_file_upload.save
		end	
		
	end

end
