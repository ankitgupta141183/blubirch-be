class LiquidationFileUploadWorker

	include Sidekiq::Worker

	def perform(liquidation_file_upload_id)

		liquidation_file_upload = LiquidationFileUpload.where("id = ?", liquidation_file_upload_id).first
		liquidation_file_upload.update(status: "Import Started")
		
		begin
			Liquidation.import_lots(liquidation_file_upload_id)
		rescue => e
			liquidation_file_upload.status = "Error"
			liquidation_file_upload.remarks = e.to_s
			liquidation_file_upload.save
		end	
		
	end

end
