class Api::V1::Warehouse::Wms::OutboundController < ApplicationController

	skip_before_action :authenticate_user! , only: [:outbound_gi_response]
  skip_before_action :check_permission
  before_action :permit_param

  def create
  	final_response = []
  	begin
			ActiveRecord::Base.transaction do				
				outbound_document = OutboundDocument.includes(outbound_document_articles: [:outbound_inventories]).where("lower(client_gatepass_number) = ?",  params[:payload].first["document_number"].try(:downcase)).last
				if (((params[:payload].size + outbound_document.outbound_document_articles.collect(&:outwarded_quantity).sum + outbound_document.outbound_document_articles.collect(&:short_quantity).sum) <= outbound_document.outbound_document_articles.collect(&:quantity).sum))
					forward_synced_requests = ForwardSyncedRequest.where(document_number: params[:payload].first["document_number"])
					if ((forward_synced_requests.size > 0) && (forward_synced_requests.collect(&:status).exclude?('Completed')))
						forward_sync_request = ForwardSyncedRequest.new(payload: params[:payload], status: "Initiated", document_number: params[:payload].first["document_number"], app_version: request.headers['HTTP_APP_VERSION'])
						if forward_sync_request.save
							OutboundDataSyncWorker.perform_in(2.seconds, forward_sync_request.id)
							params[:payload].each do |payload_param|
								final_response << {document_number: payload_param["document_number"], sku_code: payload_param["sku_code"], item_number: payload_param["item_number"], uid: payload_param["uid"], message: "Success", code: 200}
							end
							render json: final_response, status: 200 and return
						else							
							final_response << {message: "Request in under process for this document", code: 422}
							render json: final_response, status: 422 and return
						end
					elsif forward_synced_requests.size == 0
						forward_sync_request = ForwardSyncedRequest.new(payload: params[:payload], status: "Initiated", document_number: params[:payload].first["document_number"], app_version: request.headers['HTTP_APP_VERSION'])
						if forward_sync_request.save
							OutboundDataSyncWorker.perform_in(2.seconds, forward_sync_request.id)
							params[:payload].each do |payload_param|
								final_response << {document_number: payload_param["document_number"], sku_code: payload_param["sku_code"], item_number: payload_param["item_number"], uid: payload_param["uid"], message: "Success", code: 200}
							end
							render json: final_response, status: 200 and return
						else							
							final_response << {message: "Error in processing the request for this document", code: 422}
							render json: final_response, status: 422 and return
						end
					else
						final_response << {message: "Error in processing request information", code: 422}
						render json: final_response, status: 422 and return
					end
				elsif outbound_document.status == "Completed" || outbound_document.status == "Received" || outbound_document.status == "Closed"
					params[:payload].each do |payload_param|
						final_response << {document_number: payload_param["document_number"], sku_code: payload_param["sku_code"], item_number: payload_param["item_number"], uid: payload_param["uid"], message: "Success", code: 200}
					end
					render json: final_response, status: 200 and return
				else
					Rails.logger.warn "----- Payload Params is #{params[:payload]} --- #{params[:payload].size.to_s}"
					final_response << {message: "Error in processing payload information", code: 422}
					render json: final_response, status: 422 and return
				end
			end
		rescue Exception => message
			Rails.logger.warn "----Outbound Data Sync Error #{message.to_s}"
			final_response << {document_number: params[:payload].first["document_number"], message: message.to_s, code: 422}
			render json: final_response, status: 422
		end
  end

	def outbound_gi_response
		gate_pass_status_closed = LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_closed).first
		outbound_documents = OutboundDocument.includes(:outbound_inventories).where("gi_batch_number = ?", params["batchnumber"])
		if outbound_documents.present?
			error = false
			document_numbers = []
			params["messages"].each do |document|
				outbound_document = outbound_documents.where("client_gatepass_number = ?", document["documentnumber"]).last
				if outbound_documents.present?
					if document["numberofitem"].to_i == document["successitemcount"].to_i
						outbound_document.update(is_error_response_received: true, is_error: false, status: gate_pass_status_closed.original_code, status_id: gate_pass_status_closed.id, synced_response_received_at: Time.now)					
						outbound_document.outbound_inventories.update_all(is_error_response_received: true, is_error: false, is_synced: true, synced_at: Time.now)
					else
						document["failureitems"].each do |failure_item|
							outbound_document.update(is_error_response_received: true, is_error: true, synced_response_received_at: Time.now)	
							outbound_inventories = outbound_document.outbound_inventories
							outbound_inventories.each do |inventory|
								failure_inventory = document["failureitems"].detect{|line_item| ((line_item["itemnumber"] == inventory.details["item_number"].to_s) && ((line_item["errormsg"] != "null") || (line_item["errormsg"] != nil)))  }
								if failure_inventory.present?
									inventory.update(is_error_response_received: true, is_error: true, error_string: failure_item["errormsg"])
								else
									inventory.update(is_error_response_received: true, is_error: false, error_string: "Issue in other line item")
								end
							end
						end
					end
				else
					error = true
					document_numbers << document["documentnumber"]
				end
			end
			if error == false
				render json: { "timestamp": Time.now.strftime("%Y%m%d_%H%M%S"),
									 		 "status": "SUCCESS",
									     "messages": "Error information with Batch Number #{params['batchnumber']} got updated successfully"}
			else
				render json: { "timestamp": Time.now.strftime("%Y%m%d_%H%M%S"),
									   	 "status": "ERROR",
									   	 "messages": "Error in finding documents #{document_numbers.join(", ")} with specified #{params['batchnumber']} Batch Number"}
			end
		else
			render json: { "timestamp": Time.now.strftime("%Y%m%d_%H%M%S"),
									   "status": "ERROR",
									   "messages": "Error in finding documents with specified #{params['batchnumber']} Batch Number"}
		end
	end

	def permit_param
    params.permit!
  end

end
