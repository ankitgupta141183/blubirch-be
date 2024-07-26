class ForwardSyncedRequest < ApplicationRecord

	# validates :document_number, uniqueness: { 
 #  	scope: :status , conditions: -> { where("status != ? or status != ?", "Partial Items Synced", "Error Processing Document") } , message: "for this request is already in process"
	# }

	 validates_uniqueness_of :document_number, conditions: -> {  where("status != ? and status != ?", "Partial Items Synced", "Error Processing Document")  }


	def self.create_forward_scanned_inventory(forward_sync_request_id)
		forward_sync_request = self.where("id = ?", forward_sync_request_id).last
		inventory_inwarded_status = LookupValue.where("code = ?", Rails.application.credentials.inventory_status_forward_inwarded).first
		inventory_grade_not_tested = LookupValue.where("code = ?", Rails.application.credentials.inventory_grade_not_tested).first
		gate_pass_status_received = LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_received).first
		gate_pass_status_scanning_in_progress = LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_scanning_in_progress).first
		gate_pass_status_assigned = LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_assigned).first
		gatepass_inventory_status_fully_received =  LookupValue.where("code = ?", Rails.application.credentials.gatepass_inventory_status_fully_received).first
		
			ActiveRecord::Base.transaction do
				
				gate_pass = GatePass.includes(gate_pass_inventories: [:client_sku_master, :inventories, :client, :distribution_center]).where("lower(client_gatepass_number) = ?",  forward_sync_request.document_number.try(:downcase)).first

				if (((forward_sync_request.payload.size + gate_pass.gate_pass_inventories.collect(&:inwarded_quantity).sum + gate_pass.gate_pass_inventories.collect(&:short_quantity).sum) <= gate_pass.gate_pass_inventories.collect(&:quantity).sum))
					
					if gate_pass.present?
						gate_pass_inventory_hash = Hash.new
						gate_pass_inventory_quantity_hash = Hash.new
						forward_sync_request.payload.each do |payload_param|
							if (gate_pass.status_id == gate_pass_status_assigned.try(:id) || (gate_pass.status_id == gate_pass_status_scanning_in_progress.try(:id)))
								if gate_pass.gate_pass_inventories.present?
									gate_pass_inventories = gate_pass.gate_pass_inventories.includes(:client, :distribution_center, :client_sku_master).where("item_number = ? and sku_code = ?", payload_param["item_number"], payload_param["sku_code"])

									gate_pass_inventory = nil
									if gate_pass_inventories.size == 1
										gate_pass_inventory = gate_pass_inventories.last
									else
										gate_pass_inventories.each do |gate_pass_inv|
											if (gate_pass_inv.quantity.to_i > (gate_pass_inv.inwarded_quantity.try(:to_i) + gate_pass_inv.short_quantity.try(:to_i)))
												if gate_pass_inventory_quantity_hash.has_key?(gate_pass_inv.id.to_s) == false
													if (gate_pass_inv.quantity.to_i >= ((gate_pass_inv.inwarded_quantity  + payload_param["inwarded_quantity"].try(:to_i)) + (gate_pass_inv.short_quantity  + payload_param["short_quantity"].try(:to_i))))
														gate_pass_inventory_quantity_hash[gate_pass_inv.id.to_s] = {inwarded_quantity: (gate_pass_inv.inwarded_quantity + payload_param["inwarded_quantity"].try(:to_i)), short_quantity: (gate_pass_inv.short_quantity + payload_param["short_quantity"].try(:to_i))}
														gate_pass_inventory = gate_pass_inv
														break
													end
												elsif gate_pass_inventory_quantity_hash.has_key?(gate_pass_inv.id.to_s) == true
													if (gate_pass_inv.quantity.to_i >= ((gate_pass_inventory_quantity_hash[gate_pass_inv.id.to_s][:inwarded_quantity]  + payload_param["inwarded_quantity"].try(:to_i)) + (gate_pass_inventory_quantity_hash[gate_pass_inv.id.to_s][:short_quantity]  + payload_param["short_quantity"].try(:to_i))))
														gate_pass_inventory_quantity_hash[gate_pass_inv.id.to_s] = {inwarded_quantity: (gate_pass_inventory_quantity_hash[gate_pass_inv.id.to_s][:inwarded_quantity]  + payload_param["inwarded_quantity"].try(:to_i)), short_quantity: (gate_pass_inventory_quantity_hash[gate_pass_inv.id.to_s][:short_quantity]  + payload_param["short_quantity"].try(:to_i))}
														gate_pass_inventory = gate_pass_inv
														break
													end
												else
													gate_pass_inventory = gate_pass_inventories.last
												end
											end
										end
									end

									if gate_pass_inventory_hash.has_key?(gate_pass_inventory.id.to_s) == false
										gate_pass_inventory_hash[gate_pass_inventory.id.to_s] = []
									end

									if gate_pass_inventory.present?
										client_sku_master = gate_pass_inventory.try(:client_sku_master)
										if client_sku_master.nil?
											client_sku_master = ClientSkuMaster.where("code = ?", payload_param["sku_code"]).first
										end

										# Create Inventories Starts
											
												details = client_sku_master.description.merge({"scan_id" => gate_pass_inventory.try(:scan_id),"ean" => payload_param["ean"], "item_number" => payload_param["item_number"]})
												tag_number = (payload_param["uid"].present? ? payload_param["uid"] : "CF-#{payload_param['document_number']}-#{SecureRandom.hex(5)}")
												gate_pass_inventory_hash[gate_pass_inventory.id.to_s] << [gate_pass_id: gate_pass_inventory.gate_pass_id, distribution_center_id: gate_pass_inventory.distribution_center_id,
																																									client_id: gate_pass_inventory.client_id, user_id: (payload_param["user_id"].present? ? payload_param["user_id"] : gate_pass_inventory.try(:gate_pass).try(:assigned_user_id)),
																																									sku_code: payload_param["sku_code"], item_description: gate_pass_inventory.item_description,
																																									grade: inventory_grade_not_tested.try(:original_code), status: inventory_inwarded_status.try(:original_code), status_id: inventory_inwarded_status.try(:id), 
																																									client_category_id: gate_pass_inventory.client_category_id, tag_number: tag_number, client_tag_number: tag_number,
																																									quantity: payload_param["inwarded_quantity"].try(:to_i), serial_number: payload_param["serial_number"], 
																																									imei1: payload_param["imei1"], imei2: payload_param["imei2"], 
																																									serial_number_2: payload_param["serial_number_2"], details: details, gate_pass_inventory_id: gate_pass_inventory.id,
																																									short_reason: payload_param["short_reason"], short_quantity: payload_param["short_quantity"].try(:to_i),
																																									synced_time: (payload_param["synced_time"].present? ? payload_param["synced_time"] : nil ), scanned_time: (payload_param["scanned_time"].present? ? payload_param["scanned_time"] : nil ),
																																									created_at: Time.now, updated_at:Time.now]
											  												
										# Create Inventories Ends
										
									end # if gate_pass_inventory.present?
								end # if gate_pass.gate_pass_inventories.present?
													
							end # if (gate_pass.status_id == gate_pass_status_assigned.try(:id) || (gate_pass.status_id == gate_pass_status_scanning_in_progress.try(:id)))
						end # params[:payload] loop

						Inventory.upsert_all(gate_pass_inventory_hash.values.flatten, unique_by: :tag_number)

						gate_pass.reload
						if gate_pass.gate_pass_inventories.collect(&:quantity).try(:sum) == (gate_pass.inventories.collect(&:quantity).collect(&:to_i).flatten.try(:sum) + gate_pass.inventories.collect(&:short_quantity).collect(&:to_i).flatten.try(:sum))
							gate_pass.update(status: gate_pass_status_received.original_code, status_id: gate_pass_status_received.id, document_submitted_time: Time.now)
							gate_pass.gate_pass_inventories.each do |gate_pass_inventory|
								gate_pass_inventory.update(inwarded_quantity: (gate_pass_inventory.inventories.collect(&:quantity).sum rescue 0), short_quantity: (gate_pass_inventory.inventories.collect(&:short_quantity).sum rescue 0),
																				   status: gatepass_inventory_status_fully_received.original_code, status_id: gatepass_inventory_status_fully_received.id)
							end
							forward_sync_request.update(status: "Completed")
						elsif gate_pass.gate_pass_inventories.collect(&:quantity).try(:sum) > (gate_pass.inventories.collect(&:quantity).collect(&:to_i).flatten.try(:sum) + gate_pass.inventories.collect(&:short_quantity).collect(&:to_i).flatten.try(:sum))
							gate_pass.update(status: gate_pass_status_scanning_in_progress.try(:original_code), status_id: gate_pass_status_scanning_in_progress.try(:id))
							gate_pass.gate_pass_inventories.each do |gate_pass_inventory|
								gate_pass_inventory.update(inwarded_quantity: (gate_pass_inventory.inventories.collect(&:quantity).sum rescue 0), short_quantity: (gate_pass_inventory.inventories.collect(&:short_quantity).sum rescue 0))																				   
							end
							forward_sync_request.update(status: "Partial Items Synced")
						else
							forward_sync_request.update(status: "Error in Updation")
						end # if gate_pass.gate_pass_inventories.present?		

					end # if gate_pass.present?				
				end # if (((params[:payload].size + gate_pass.gate_pass_inventories.collect(&:inwarded_quantity).sum + gate_pass.gate_pass_inventories.collect(&:short_quantity).sum) <= gate_pass.gate_pass_inventories.collect(&:quantity).sum) && ((forward_sync_requests.size == 0) || (forward_sync_requests.present? && (forward_sync_requests.last.status == "Partial Items Synced" || forward_sync_requests.last.status != "Initiated"))))
			end # Transaction End Block
	end

	def self.create_outbound_scanned_inventory(forward_sync_request_id)
		forward_sync_request = self.where("id = ?", forward_sync_request_id).last
		inventory_inwarded_status = LookupValue.where("code = ?", Rails.application.credentials.inventory_status_forward_inwarded).first
		inventory_grade_not_tested = LookupValue.where("code = ?", Rails.application.credentials.inventory_grade_not_tested).first
		gate_pass_status_received = LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_received).first
		gate_pass_status_scanning_in_progress = LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_scanning_in_progress).first
		gate_pass_status_assigned = LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_assigned).first
		gatepass_inventory_status_fully_received =  LookupValue.where("code = ?", Rails.application.credentials.gatepass_inventory_status_fully_received).first
			
			ActiveRecord::Base.transaction do
				
				outbound_document = OutboundDocument.includes(outbound_document_articles: [:client_sku_master, :outbound_inventories, :client, :distribution_center]).where("lower(client_gatepass_number) = ?",  forward_sync_request.document_number.try(:downcase)).first

				if (((forward_sync_request.payload.size + outbound_document.outbound_document_articles.collect(&:outwarded_quantity).sum + outbound_document.outbound_document_articles.collect(&:short_quantity).sum) <= outbound_document.outbound_document_articles.collect(&:quantity).sum))
										
					if outbound_document.present?
						outbound_document_article_hash = Hash.new
						forward_sync_request.payload.each do |payload_param|
							if (outbound_document.status_id == gate_pass_status_assigned.try(:id) || (outbound_document.status_id == gate_pass_status_scanning_in_progress.try(:id)))
								if outbound_document.outbound_document_articles.present?
									outbound_document_article = outbound_document.outbound_document_articles.includes(:client, :distribution_center, :client_sku_master).where("item_number = ? and sku_code = ?", payload_param["item_number"], payload_param["sku_code"]).first
									if outbound_document_article_hash.has_key?(outbound_document_article.id.to_s) == false
										outbound_document_article_hash[outbound_document_article.id.to_s] = []
									end
									if outbound_document_article.present?
										client_sku_master = outbound_document_article.try(:client_sku_master)
										if client_sku_master.nil?
											client_sku_master = ClientSkuMaster.where("code = ?", payload_param["sku_code"]).last
										end

										# Create Inventories Starts
											
												details = client_sku_master.description.merge({"scan_id" => outbound_document_article.try(:scan_id),"ean" => payload_param["ean"], "item_number" => payload_param["item_number"]})
												tag_number = (payload_param["uid"].present? ? payload_param["uid"] : "CF-#{payload_param['document_number']}-#{SecureRandom.hex(5)}")
												outbound_document_article_hash[outbound_document_article.id.to_s] <<  [ outbound_document_id: outbound_document_article.outbound_document_id, distribution_center_id: outbound_document_article.distribution_center_id,
																																																client_id: outbound_document_article.client_id, user_id: (payload_param["user_id"].present? ? payload_param["user_id"] : outbound_document_article.try(:outbound_document).try(:assigned_user_id)),
																																																sku_code: payload_param["sku_code"], item_description: outbound_document_article.item_description,
																																																grade: inventory_grade_not_tested.try(:original_code), status: inventory_inwarded_status.try(:original_code), status_id: inventory_inwarded_status.try(:id), 
																																																client_category_id: outbound_document_article.client_category_id, tag_number: tag_number, client_tag_number: tag_number,
																																																quantity: payload_param["outwarded_quantity"].try(:to_i), serial_number: payload_param["serial_number"], 
																																																imei1: payload_param["imei1"], imei2: payload_param["imei2"], 
																																																details: details, outbound_document_article_id: outbound_document_article.id,
																																																short_reason: payload_param["short_reason"], short_quantity: payload_param["short_quantity"].try(:to_i),
																																																synced_time: (payload_param["synced_time"].present? ? payload_param["synced_time"] : nil ), scanned_time: (payload_param["scanned_time"].present? ? payload_param["scanned_time"] : nil ),
																																																aisle_location: outbound_document_article.aisle_location, created_at: Time.now, updated_at:Time.now ]
																			

										# Create Inventories Ends
									end # if outbound_document_article.present?
								end # if outbound_document.outbound_document_articles.present?
								
							end # if (outbound_document.status_id == gate_pass_status_assigned.try(:id) || (outbound_document.status_id == gate_pass_status_scanning_in_progress.try(:id)))
						end # params[:payload] loop

						OutboundInventory.upsert_all(outbound_document_article_hash.values.flatten, unique_by: :tag_number)

						outbound_document.reload
						if outbound_document.outbound_document_articles.collect(&:quantity).try(:sum) == (outbound_document.outbound_inventories.collect(&:quantity).collect(&:to_i).flatten.try(:sum) + outbound_document.outbound_inventories.collect(&:short_quantity).collect(&:to_i).flatten.try(:sum))
							outbound_document.update(status: gate_pass_status_received.original_code, status_id: gate_pass_status_received.id, document_submitted_time: Time.now)
							outbound_document.outbound_document_articles.each do |outbound_document_article|
								outbound_document_article.update(outwarded_quantity: (outbound_document_article.outbound_inventories.collect(&:quantity).sum rescue 0), short_quantity: (outbound_document_article.outbound_inventories.collect(&:short_quantity).sum rescue 0),
																								status: gatepass_inventory_status_fully_received.original_code, status_id: gatepass_inventory_status_fully_received.id)
							end
							forward_sync_request.update(status: "Completed")
						elsif outbound_document.outbound_document_articles.collect(&:quantity).try(:sum) > (outbound_document.outbound_inventories.collect(&:quantity).collect(&:to_i).flatten.try(:sum) + outbound_document.outbound_inventories.collect(&:short_quantity).collect(&:to_i).flatten.try(:sum))
							outbound_document.update(status: gate_pass_status_scanning_in_progress.try(:original_code), status_id: gate_pass_status_scanning_in_progress.try(:id))
							outbound_document.outbound_document_articles.each do |outbound_document_article|
								outbound_document_article.update(outwarded_quantity: (outbound_document_article.outbound_inventories.collect(&:quantity).sum rescue 0), short_quantity: (outbound_document_article.outbound_inventories.collect(&:short_quantity).sum rescue 0))
							end
							forward_sync_request.update(status: "Partial Items Synced")
						else
							forward_sync_request.update(status: "Error in Updation")
						end 

					end # if outbound_document.present?				
				end # if (((forward_sync_request.payload.size + outbound_document.outbound_document_articles.collect(&:outwarded_quantity).sum + outbound_document.outbound_document_articles.collect(&:short_quantity).sum) <= outbound_document.outbound_document_articles.collect(&:quantity).sum))
			end # Transaction End Block
	end

end
