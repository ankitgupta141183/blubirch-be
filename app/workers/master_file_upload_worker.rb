class MasterFileUploadWorker

	include Sidekiq::Worker

	def perform(master_file_upload_id)
		master_file_upload = MasterFileUpload.where("id = ?", master_file_upload_id).first
		master_file_upload.update(status: "Import Started") unless master_file_upload.retrying?
		if(master_file_upload.master_file_type == "Category Test Rule")
			CategoryGradingRule.import_test_rule(master_file_upload)
		elsif(master_file_upload.master_file_type == "Category Grading Rule")
			CategoryGradingRule.import_grading_rule(master_file_upload,master_file_upload.grading_type)	
		elsif(master_file_upload.master_file_type == "Client Category Test Rule")
			ClientCategoryGradingRule.import_client_test_rule(master_file_upload)
		elsif(master_file_upload.master_file_type == "Client Category Grading Rule")
			ClientCategoryGradingRule.import_client_grading_rule(master_file_upload,master_file_upload.grading_type)				
		elsif (master_file_upload.master_file_type == "Gate Pass")
			GatePass.import_new(master_file_upload_id)
		elsif (master_file_upload.master_file_type == "Return Inventory Information")
			ReturnInventoryInformation.import(master_file_upload_id)
		elsif (master_file_upload.master_file_type == "Exceptional Article Serial Number")
			ExceptionalArticleSerialNumber.import(master_file_upload_id)
		elsif (master_file_upload.master_file_type == "Exceptional Article")
			ExceptionalArticle.import(master_file_upload_id)
		elsif (master_file_upload.master_file_type == "Alert Configurations")
			AlertConfiguration.import(master_file_upload_id,master_file_upload.distribution_center_id)
		elsif (master_file_upload.master_file_type == "Pending Receipt Document")
			PendingReceiptDocument.import_file(master_file_upload)
		elsif (master_file_upload.master_file_type == "Update PRD Items")
			PendingReceiptDocument.update_prd_items(master_file_upload)
		else
			begin
				if master_file_upload.present?
				  temp_file = open(master_file_upload.master_file.url)
				  file = File.new(temp_file)
				  #data = CSV.read(file.path, {headers: true, encoding: "iso-8859-1:utf-8"})
				end
				if (master_file_upload.master_file_type == "Category")
					Category.import_categories(file)
				elsif (master_file_upload.master_file_type == "Attribute Master")
					AttributeMaster.import_attributes(file)
				elsif (master_file_upload.master_file_type == "Client Attribute Master")
					ClientAttributeMaster.import_client_attributes(file,master_file_upload.client_id)
				elsif (master_file_upload.master_file_type == "Client Category")
					ClientCategory.import_client_categories(file,master_file_upload.client_id)
				elsif (master_file_upload.master_file_type == "Lookup Key")
				  LookupKey.import(file)
				elsif (master_file_upload.master_file_type == "Lookup Value")
					LookupValue.import(file)
				elsif (master_file_upload.master_file_type == "Client Category Mapping")
					ClientCategoryMapping.import(file)
				elsif (master_file_upload.master_file_type == "Cost Value")
					CostValue.import(file)
				elsif (master_file_upload.master_file_type == "Order")
					Order.import(file)
				elsif (master_file_upload.master_file_type == "Customer Return Reason")
					CustomerReturnReason.import(file)	
				elsif (master_file_upload.master_file_type == "Email Template")
					EmailTemplate.import(file)	
				elsif (master_file_upload.master_file_type == "Invoice")
					Invoice.import(file)	
				elsif (master_file_upload.master_file_type == "Reminder")
					Reminder.import(file)
				elsif (master_file_upload.master_file_type == "Store Master")
					DistributionCenter.create_centers(master_file_upload.id, 678)
				elsif (master_file_upload.master_file_type == "Client Sku Master")
					ClientSkuMaster.import_client_sku_masters(master_file_upload.id)
				elsif (master_file_upload.master_file_type == "Vendor Master")
					VendorMaster.import(master_file_upload.id)
        elsif (master_file_upload.master_file_type == "Vendor Rate Card")
          VendorRateCard.import(master_file_upload.id)
        end
      rescue => e
				master_file_upload.status = "Error"
				master_file_upload.remarks = e.to_s
				master_file_upload.save
			end	
		end
	end

end
