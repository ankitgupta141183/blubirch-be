class InventoryFileUploadWorker

  include Sidekiq::Worker

  def perform(inventory_file_upload_id)

    inventory_file_upload_id = InventoryFileUpload.where("id = ?", inventory_file_upload_id).first
    begin
      if inventory_file_upload_id.inward_type == "B2B Email"
        InventoryFileUpload.import_email_lots(inventory_file_upload_id)
      elsif inventory_file_upload_id.inward_type == "B2B Auction"
        InventoryFileUpload.import_lots(inventory_file_upload_id)
      elsif inventory_file_upload_id.inward_type == "Edit Grade"
        InventoryFileUpload.edit_grade(inventory_file_upload_id)
      elsif inventory_file_upload_id.inward_type == "B2B Contract"
        InventoryFileUpload.import_contract_lots(inventory_file_upload_id)
      elsif inventory_file_upload_id.inward_type == "Competitive Lot"
        InventoryFileUpload.import_competitive_lots(inventory_file_upload_id)
      end
    rescue => e
      inventory_file_upload_id.update_columns(status: "Failed", remarks: e.to_s)
    end 
    
  end

end
