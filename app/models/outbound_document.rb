class OutboundDocument < ApplicationRecord

	acts_as_paranoid
  belongs_to :distribution_center, optional: true
  belongs_to :user, optional: true
  belongs_to :client, optional: true
  belongs_to :master_data_input, optional: true
  belongs_to :assigned_user, optional: true, class_name: "User", foreign_key: :assigned_user_id
  belongs_to :outbound_document_status, class_name: "LookupValue", foreign_key: :status_id

  has_many :outbound_inventories
  has_many :outbound_document_articles

  validates :client_gatepass_number, :document_type, :document_date, :source_code, presence: true
  validates :client_gatepass_number, uniqueness: true
  validates :destination_code, presence: true , if: -> {document_type != "ZRTN" }

  include Filterable
  include JsonUpdateable


  def self.create_master_data(master_data_id)
    master_data = MasterDataInput.where("id = ?", master_data_id).first    
    gatepass_pending_receipt_status =  LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_pending_receipt).first
    client = Client.first
    user = User.first
    if master_data.present?
      pickslip_document_type = LookupValue.where("code = ?", Rails.application.credentials.pickslip_document_code).first
      errors_hash = Hash.new(nil)
      errors_hash["batchnumber"] = master_data.payload["batch_number"]
      errors_hash["errortype"] = "OUTWARDS"
      errors_hash["messages"] = []
      error_messages = []
      error_found = false
      success_count = 0
      failed_count = 0
      begin
        # ActiveRecord::Base.transaction do
          master_data.payload["payload"].each do |outbound_document_params|          
            move_to_next = false
            if pickslip_document_type.try(:original_code) == outbound_document_params["document_type"]

              source = DistributionCenter.where("code = ?" , outbound_document_params["source_code"]).last
              destination = DistributionCenter.where("code = ?" , outbound_document_params["destination_code"]).last
              # errors_hash.merge!(outbound_document_params["client_gatepass_number"] => [])
              if outbound_document_params["destination_code"].blank?
                destination_error = "Destination Code is missing"
              elsif destination.nil?
                destination_error = "Destination Code is not found in Blubirch system"
              end
              if outbound_document_params["source_code"].blank?
                source_error = "Source Code is missing"
              elsif source.nil?
                source_error = "Source Code is not found in Blubirch system"
              end
              if outbound_document_params["client_gatepass_number"].blank?
                document_number_error = "Document Number is missing"
              end
              if outbound_document_params["document_type"].blank?
                document_type_error = "Document Type is missing"
              end
              
              next if move_to_next
                  
                  outbound_document = OutboundDocument.includes(:outbound_document_articles).where(document_type_id: pickslip_document_type.id, client_gatepass_number: outbound_document_params["client_gatepass_number"]).last

                  if outbound_document.nil? #if move_to_next ==  false && outbound_document.nil?
                    outbound_document = OutboundDocument.new(document_type_id: pickslip_document_type.id, document_type: pickslip_document_type.original_code, 
                                             client_gatepass_number: outbound_document_params["client_gatepass_number"], document_date: outbound_document_params["received_date"].try(:to_datetime), 
                                             client_id: client.try(:id), user_id: user.try(:id), status_id: gatepass_pending_receipt_status.id, 
                                             status: gatepass_pending_receipt_status.original_code, distribution_center_id: destination.try(:id), destination_id: destination.try(:id),
                                             destination_code: outbound_document_params["destination_code"], destination_address: (destination.present? ? destination.try(:address) : nil),
                                             destination_city: destination.try(:city).try(:original_code), destination_state: destination.try(:state).try(:original_code), 
                                             destination_country: destination.try(:country).try(:original_code), gatepass_number: "GP-#{SecureRandom.hex(3)}",
                                             source_code: outbound_document_params["source_code"], source_id: source.try(:id),
                                             source_address: (source.present? ? source.try(:address) : nil), source_city: source.try(:city).try(:original_code), 
                                             source_state: source.try(:state).try(:original_code), 
                                             source_country: source.try(:country).try(:original_code), is_forward: true,
                                             batch_number: master_data.payload["batch_number"], master_data_input_id: master_data.id)

                    error_found , response_error_messages = self.create_items(outbound_document_params["item_list"], outbound_document, error_messages, destination, destination_error, document_number_error, document_type_error, source_error)
                    errors_hash["messages"] << response_error_messages
                    
                  elsif outbound_document.present? && outbound_document.try(:status_id) == gatepass_pending_receipt_status.id

                    if outbound_document.update( document_type_id: pickslip_document_type.id, document_type: pickslip_document_type.original_code, 
                                         client_gatepass_number: outbound_document_params["client_gatepass_number"], document_date: outbound_document_params["received_date"].try(:to_datetime), 
                                         client_id: client.try(:id), user_id: user.try(:id), status_id: gatepass_pending_receipt_status.id, 
                                         status: gatepass_pending_receipt_status.original_code, distribution_center_id: destination.try(:id), destination_id: destination.try(:id),
                                         destination_code: outbound_document_params["destination_code"], destination_address: (destination.present? ? destination.try(:address) : nil),
                                         destination_city: destination.try(:city).try(:original_code), destination_state: destination.try(:state).try(:original_code), 
                                         destination_country: destination.try(:country).try(:original_code), gatepass_number: "GP-#{SecureRandom.hex(3)}",
                                         source_code: outbound_document_params["source_code"], source_id: source.try(:id),
                                         source_address: (source.present? ? source.try(:address) : nil), source_city: source.try(:city).try(:original_code), 
                                         source_state: source.try(:state).try(:original_code), 
                                         source_country: source.try(:country).try(:original_code), is_forward: true,
                                         batch_number: master_data.payload["batch_number"], master_data_input_id: master_data.id)

                      if outbound_document.outbound_document_articles.present?
                        outbound_document.outbound_document_articles.each do |oba|
                          oba.really_destroy!
                        end
                      end

                      error_found , response_error_messages = self.create_items(outbound_document_params["item_list"], outbound_document, error_messages, destination, destination_error, document_number_error, document_type_error, source_error)
                      errors_hash["messages"] << response_error_messages
                    end

                  end

                if error_found == false
                  success_count = success_count + 1
                else
                  failed_count = failed_count + 1
                end

            end # if ibd_document_type.try(:original_code) == outbound_document_params[:document_type]
          end #master_data.payload
        #   raise ActiveRecord::Rollback, "Please check error hash" if error_found
        # end # ActiveRecord::Base.transaction do 
      rescue Exception => message
        master_data.update(status: "Failed", remarks: message.to_s, is_error: true, success_count: success_count, failed_count: failed_count) if master_data.present? 
      else
        master_data.update(status: "Completed", is_error: false, remarks: errors_hash, success_count: success_count, failed_count: failed_count) if master_data.present?
      ensure  
        if error_found
          master_data.update(status: "Failed", remarks: errors_hash, is_error: true, success_count: success_count, failed_count: failed_count) if master_data.present?
        end

        response_payload = {errors_hash: errors_hash, master_data_input_id: master_data.id}

        # Push Response to SAP Via APIM Starts by calling CRON Server
        if Rails.env == "production"
        	response = RestClient::Request.execute(:method => :post, :url => "#{Rails.application.credentials.cron_server_url}/api/v1/doc_error_response" , :payload => response_payload, :timeout => 9000000, :headers => {"Content-Type": "application/json"})  
        else
        	headers = {"IntegrationType" => "INBDERROR", "Ocp-Apim-Subscription-Key" => Rails.application.credentials.sap_subscription_key }
        	response = RestClient::Request.execute(:method => :post, :url => Rails.application.credentials.inbound_sap_error_apim_end_point, :payload => errors_hash.to_json, :timeout => 9000000, :headers => headers)
          parsed_response = JSON.parse(response)
          master_data.update(is_response_pushed: true) if parsed_response["status"] == "SUCCESS"
        end	
        # Push Response to SAP Via APIM Ends by calling CRON Server

        
      end  # begin end
    end # if master_data.present?
  end # Method End

  def self.create_items(items_array, outbound_document, error_messages, destination, destination_error = nil, document_number_error = nil, document_type_error = nil, source_error = nil)
    gatepass_inventory_pending_receipt_status =  LookupValue.where("code = ?", Rails.application.credentials.gatepass_inventory_status_pending_receipt).first
    success_item_count = 0
    failure_item_count = 0
    failure_items = []
    success_items = []

    success_item_error = {"successmsg": "null"}     
    items_array.each do |outbound_document_item_params|
      scan_id = outbound_document_item_params["scan_id"]
      serial_number_length = 0
      error = false
      error_code = []
      client_sku_master = ClientSkuMaster.includes(:client_category, :sku_eans).where("code = ?", outbound_document_item_params["sku_code"]).last
      exceptional_article = ExceptionalArticle.where("sku_code ilike (?)", "%#{outbound_document_item_params['sku_code'].sub(/^[0]+/,'')}%").last
      exceptional_article_serial_number = ExceptionalArticleSerialNumber.where("sku_code ilike (?)", "%#{outbound_document_item_params['sku_code'].sub(/^[0]+/,'')}%").last
      if exceptional_article.present?
        scan_id = ((exceptional_article.scan_id.present?) ? exceptional_article.scan_id : outbound_document_item_params["scan_id"])
      else
        scan_id = outbound_document_item_params["scan_id"]
      end
      if exceptional_article_serial_number.present?
        serial_number_length = ((exceptional_article_serial_number.serial_number_length > 0) ? exceptional_article_serial_number.serial_number_length : 0)
      else
        serial_number_length = 0
      end
      if outbound_document_item_params["sku_code"].blank?
        error = true
        error_code << "01"
      end
      if client_sku_master.nil?
        error = true
        error_code << "02"        
      end
      if outbound_document_item_params["quantity"].blank?
        error = true
        error_code << "03"        
      end
      if outbound_document_item_params["scan_id"].blank?
        error = true
        error_code << "04"        
      end
      if outbound_document_item_params["location"].blank?
        error = true
        error_code << "05"
      end
      if document_number_error.present? && document_number_error == "Document Number is missing"
        error = true
        error_code << "06"        
      end
      if document_type_error.present? && document_type_error == "Document Type is missing"
        error = true
        error_code << "07"        
      end
      if destination_error.present? && destination_error == "Destination Code is missing"
        error = true
        error_code << "08"        
      elsif destination_error.present? && destination_error == "Destination Code is not found in Blubirch system"
        error = true
        error_code << "09"
      end
      if source_error.present? && (source_error == "Source Code is missing")
        error = true
        error_code << "10"        
      elsif source_error.present? && source_error == "Source Code is not found in Blubirch system"
        error = true
        error_code << "11"
      end
      if outbound_document_item_params["item_number"].blank?
        error = true
        error_code << "12"
      end
      if error == false
        outbound_document.outbound_document_articles.build(sku_code: outbound_document_item_params["sku_code"], scan_id: scan_id,
                                              quantity: outbound_document_item_params["quantity"], item_description: (outbound_document_item_params["sku_description"].present? ? outbound_document_item_params["sku_description"] : client_sku_master.sku_description), 
                                              merchandise_category: (outbound_document_item_params["category_code"].present? ? outbound_document_item_params["category_code"] : client_sku_master.description["category_code_l3"]), merch_cat_desc: outbound_document_item_params["sku_description"],
                                              line_item: (outbound_document_item_params["category_code"].present? ? outbound_document_item_params["category_code"] : client_sku_master.description["category_code_l3"]),
                                              client_category_id: client_sku_master.client_category_id, brand: client_sku_master.brand, aisle_location: outbound_document_item_params["location"],
                                              client_category_name: client_sku_master.client_category.name, client_sku_master_id: client_sku_master.id,
                                              item_number: outbound_document_item_params["item_number"], outwarded_quantity: 0, status: gatepass_inventory_pending_receipt_status.original_code, 
                                              status_id: gatepass_inventory_pending_receipt_status.id, distribution_center_id: destination.id, 
                                              client_id: outbound_document.client_id, user_id: outbound_document.user_id, details: {"own_label"=> client_sku_master.own_label },
                                              sku_eans: client_sku_master.sku_eans.collect(&:ean).flatten, imei_flag: (client_sku_master.try(:imei_flag).present? ? client_sku_master.try(:imei_flag) : "0"),
                                              serial_number_length: serial_number_length)
        success_item_count = success_item_count + 1
        # failure_items << { "itemnumber": outbound_document_item_params["item_number"].to_s, "errormsg": "null" }
      else
        failure_item_count = failure_item_count + 1

        concat_error_messages = "null"
        if error_code.present?
          error_string = []
          error_string << "Article" if (error_code.include?("01"))
          error_string << "Quantity" if (error_code.include?("03")) 
          error_string << "ScanInd" if (error_code.include?("04"))
          error_string << "Location" if (error_code.include?("05"))
          error_string << "DocumentNumber" if (error_code.include?("06")) 
          error_string << "DocumentType" if (error_code.include?("07"))
          error_string << "ReceivingSite" if (error_code.include?("08")) 
          error_string << "SupplyingSite" if (error_code.include?("10"))
          error_string << "ItemNumber" if (error_code.include?("12"))
          if error_string.present?
            concat_error_messages = (error_string.join(",") + " " + "is missing")
            error_string = [concat_error_messages]
          end

          
          error_string << "Article is not present in Blubirch system"  if (error_code.include?("02"))
          error_string << "ReceivingSite is not present in Blubirch system"  if (error_code.include?("09"))
          error_string << "SupplyingSite is not present in Blubirch system"  if (error_code.include?("11"))      
          concat_error_messages = error_string.join("|")
        end

        failure_items << { "itemnumber": outbound_document_item_params["item_number"].to_s, "errormsg": concat_error_messages }
      end      
    end

    if ((failure_item_count == 0) && outbound_document.valid?)
      if outbound_document.save
        if (success_item_error[:successmsg] == "null")
          success_item_error[:successmsg] = "DocumentNumber #{outbound_document.client_gatepass_number} is posted successfully."
        end
        success_items << success_item_error 
        failure_items << { "itemnumber": "null", "errormsg": "null" }
        document_hash = {"documentnumber": outbound_document.client_gatepass_number, "numberofitem": items_array.size.to_s, "successitemcount": success_item_count.to_s, "failureitemcount": failure_item_count.to_s, "failureitems": failure_items.flatten, "success": success_items.flatten}
        error_messages = document_hash
        return false, error_messages       
      else
        success_items << success_item_error
        success_item_count = 0
        document_hash = {"documentnumber": outbound_document.client_gatepass_number, "numberofitem": items_array.size.to_s, "successitemcount": success_item_count.to_s, "failureitemcount": failure_item_count.to_s, "failureitems": failure_items.flatten, "success": success_items.flatten}
        error_messages = document_hash
        return true, error_messages
      end
    elsif failure_item_count != 0
      success_items << success_item_error
      success_item_count = 0
      # failure_items.flat_map { |failure_item| failure_item[:errormsg] = "Not processed due to Master data issue in document" if failure_item[:errormsg] == "null" }
      document_hash = {"documentnumber": outbound_document.client_gatepass_number, "numberofitem": items_array.size.to_s, "successitemcount": success_item_count.to_s, "failureitemcount": failure_item_count.to_s, "failureitems": failure_items.flatten, "success": success_items.flatten}
      error_messages = document_hash
      return true, error_messages
    end
  end

  def self.create_rtn_master_data(master_data_id)
    master_data = MasterDataInput.where("id = ?", master_data_id).first    
    gatepass_pending_receipt_status =  LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_pending_receipt).first
    client = Client.first
    user = User.first
    if master_data.present?
      rtn_document_type = LookupValue.where("code = ?", Rails.application.credentials.rtn_document_code).first
      errors_hash = Hash.new(nil)
      errors_hash["batchnumber"] = master_data.payload["batch_number"]
      errors_hash["errortype"] = "OUTWARDS"
      errors_hash["messages"] = []
      error_messages = []
      error_found = false
      success_count = 0
      failed_count = 0
      begin
        # ActiveRecord::Base.transaction do
          master_data.payload["payload"].each do |outbound_document_params|          
            move_to_next = false
            if rtn_document_type.try(:original_code) == outbound_document_params["document_type"]

              source = DistributionCenter.where("code = ?" , outbound_document_params["source_code"]).last
              # errors_hash.merge!(outbound_document_params["client_gatepass_number"] => [])
              
              if outbound_document_params["source_code"].blank?
                source_error = "Source Code is missing"
              elsif source.nil?
                source_error = "Source Code is not found in Blubirch system"
              end
              if outbound_document_params["client_gatepass_number"].blank?
                document_number_error = "Document Number is missing"
              end
              if outbound_document_params["document_type"].blank?
                document_type_error = "Document Type is missing"
              end
              if outbound_document_params["vendor_code"].blank?
                destination_code_error = "Vendor Code is missing"
              end
              if outbound_document_params["original_invoice"].blank?
                original_invoice_error = "Original Invoice is missing"
              end
              next if move_to_next
                  
                  outbound_document = OutboundDocument.includes(:outbound_document_articles).where(document_type_id: rtn_document_type.id, client_gatepass_number: outbound_document_params["client_gatepass_number"]).last

                  if outbound_document.nil? #if move_to_next ==  false && outbound_document.nil?
                    outbound_document = OutboundDocument.new(document_type_id: rtn_document_type.id, document_type: rtn_document_type.original_code, 
                                             client_gatepass_number: outbound_document_params["client_gatepass_number"], document_date: outbound_document_params["dispatch_date"].try(:to_datetime), 
                                             client_id: client.try(:id), user_id: user.try(:id), status_id: gatepass_pending_receipt_status.id, 
                                             status: gatepass_pending_receipt_status.original_code, distribution_center_id: source.try(:id), gatepass_number: "GP-#{SecureRandom.hex(3)}",
                                             source_code: outbound_document_params["source_code"], source_id: source.try(:id),
                                             source_address: (source.present? ? source.try(:address) : nil), source_city: source.try(:city).try(:original_code), 
                                             source_state: source.try(:state).try(:original_code), 
                                             source_country: source.try(:country).try(:original_code), is_forward: true, vendor_code: outbound_document_params["vendor_code"],
                                             vendor_name: outbound_document_params["vendor_name"], batch_number: master_data.payload["batch_number"], 
                                             master_data_input_id: master_data.id, original_invoice: outbound_document_params["original_invoice"])

                    error_found , response_error_messages = self.create_rtn_items(outbound_document_params["item_list"], outbound_document, error_messages, source, destination_code_error, document_number_error, document_type_error, source_error, original_invoice_error)
                    errors_hash["messages"] << response_error_messages
                    
                  elsif outbound_document.present? && outbound_document.try(:status_id) == gatepass_pending_receipt_status.id

                    if outbound_document.update( document_type_id: rtn_document_type.id, document_type: rtn_document_type.original_code, 
                                         client_gatepass_number: outbound_document_params["client_gatepass_number"], document_date: outbound_document_params["dispatch_date"].try(:to_datetime), 
                                         client_id: client.try(:id), user_id: user.try(:id), status_id: gatepass_pending_receipt_status.id, 
                                         status: gatepass_pending_receipt_status.original_code, distribution_center_id: source.try(:id), gatepass_number: "GP-#{SecureRandom.hex(3)}",
                                         source_code: outbound_document_params["source_code"], source_id: source.try(:id),
                                         source_address: (source.present? ? source.try(:address) : nil), source_city: source.try(:city).try(:original_code), 
                                         source_state: source.try(:state).try(:original_code), 
                                         source_country: source.try(:country).try(:original_code), is_forward: true, vendor_code: outbound_document_params["vendor_code"],
                                         vendor_name: outbound_document_params["vendor_name"], batch_number: master_data.payload["batch_number"], 
                                         master_data_input_id: master_data.id, original_invoice: outbound_document_params["original_invoice"])

                      if outbound_document.outbound_document_articles.present?
                        outbound_document.outbound_document_articles.each do |oba|
                          oba.really_destroy!
                        end
                      end

                      error_found , response_error_messages = self.create_rtn_items(outbound_document_params["item_list"], outbound_document, error_messages, source, destination_code_error, document_number_error, document_type_error, source_error, original_invoice_error)
                      errors_hash["messages"] << response_error_messages
                    end

                  end

                if error_found == false
                  success_count = success_count + 1
                else
                  failed_count = failed_count + 1
                end

            end # if ibd_document_type.try(:original_code) == outbound_document_params[:document_type]
          end #master_data.payload
        #   raise ActiveRecord::Rollback, "Please check error hash" if error_found
        # end # ActiveRecord::Base.transaction do 
      rescue Exception => message
        master_data.update(status: "Failed", remarks: message.to_s, is_error: true, success_count: success_count, failed_count: failed_count) if master_data.present? 
      else
        master_data.update(status: "Completed", is_error: false, remarks: errors_hash, success_count: success_count, failed_count: failed_count) if master_data.present?
      ensure  
        if error_found
          master_data.update(status: "Failed", remarks: errors_hash, is_error: true, success_count: success_count, failed_count: failed_count) if master_data.present?
        end

        response_payload = {errors_hash: errors_hash, master_data_input_id: master_data.id}

        # Push Response to SAP Via APIM Starts by calling CRON Server
        if Rails.env == "production"
          response = RestClient::Request.execute(:method => :post, :url => "#{Rails.application.credentials.cron_server_url}/api/v1/doc_error_response" , :payload => response_payload, :timeout => 9000000, :headers => {"Content-Type": "application/json"})  
        else
          headers = {"IntegrationType" => "INBDERROR", "Ocp-Apim-Subscription-Key" => Rails.application.credentials.sap_subscription_key }
          response = RestClient::Request.execute(:method => :post, :url => Rails.application.credentials.inbound_sap_error_apim_end_point, :payload => errors_hash.to_json, :timeout => 9000000, :headers => headers)
          parsed_response = JSON.parse(response)
          master_data.update(is_response_pushed: true) if parsed_response["status"] == "SUCCESS"
        end 
        # Push Response to SAP Via APIM Ends by calling CRON Server

        
      end  # begin end
    end # if master_data.present?
  end # Method End


  def self.create_rtn_items(items_array, outbound_document, error_messages, source, destination_error = nil, document_number_error = nil, document_type_error = nil, source_error = nil, original_invoice_error = nil)
    gatepass_inventory_pending_receipt_status =  LookupValue.where("code = ?", Rails.application.credentials.gatepass_inventory_status_pending_receipt).first
    success_item_count = 0
    failure_item_count = 0
    failure_items = []
    success_items = []

    success_item_error = {"successmsg": "null"}     
    items_array.each do |outbound_document_item_params|
      scan_id = outbound_document_item_params["scan_id"]
      serial_number_length = 0
      error = false
      error_code = []
      client_sku_master = ClientSkuMaster.includes(:client_category, :sku_eans).where("code = ?", outbound_document_item_params["sku_code"]).last
      exceptional_article = ExceptionalArticle.where("sku_code ilike (?)", "%#{outbound_document_item_params['sku_code'].sub(/^[0]+/,'')}%").last
      exceptional_article_serial_number = ExceptionalArticleSerialNumber.where("sku_code ilike (?)", "%#{outbound_document_item_params['sku_code'].sub(/^[0]+/,'')}%").last
      if exceptional_article.present?
        scan_id = ((exceptional_article.scan_id.present?) ? exceptional_article.scan_id : outbound_document_item_params["scan_id"])
      else
        scan_id = outbound_document_item_params["scan_id"]
      end
      if exceptional_article_serial_number.present?
        serial_number_length = ((exceptional_article_serial_number.serial_number_length > 0) ? exceptional_article_serial_number.serial_number_length : 0)
      else
        serial_number_length = 0
      end
      if outbound_document_item_params["sku_code"].blank?
        error = true
        error_code << "01"
      end
      if client_sku_master.nil?
        error = true
        error_code << "02"        
      end
      if outbound_document_item_params["quantity"].blank?
        error = true
        error_code << "03"        
      end
      if outbound_document_item_params["scan_id"].blank?
        error = true
        error_code << "04"        
      end
      if original_invoice_error.present? && (original_invoice_error == "Original Invoice is missing")
        error = true
        error_code << "05"
      end
      if document_number_error.present? && document_number_error == "Document Number is missing"
        error = true
        error_code << "06"        
      end
      if document_type_error.present? && document_type_error == "Document Type is missing"
        error = true
        error_code << "07"        
      end
      if destination_error.present? && ((destination_error == "Destination Code is missing") || (destination_error == "Vendor Code is missing"))
        error = true
        error_code << "08"        
      elsif destination_error.present? && destination_error == "Destination Code is not found in Blubirch system"
        error = true
        error_code << "09"
      end
      if source_error.present? && (source_error == "Source Code is missing")
        error = true
        error_code << "10"        
      elsif source_error.present? && source_error == "Source Code is not found in Blubirch system"
        error = true
        error_code << "11"
      end
      if outbound_document_item_params["item_number"].blank?
        error = true
        error_code << "12"
      end
      if error == false
        outbound_document.outbound_document_articles.build(sku_code: outbound_document_item_params["sku_code"], scan_id: scan_id,
                                              quantity: outbound_document_item_params["quantity"], item_description: (outbound_document_item_params["sku_description"].present? ? outbound_document_item_params["sku_description"] : client_sku_master.sku_description), 
                                              merchandise_category: (outbound_document_item_params["category_code"].present? ? outbound_document_item_params["category_code"] : client_sku_master.description["category_code_l3"]), merch_cat_desc: outbound_document_item_params["sku_description"],
                                              line_item: (outbound_document_item_params["category_code"].present? ? outbound_document_item_params["category_code"] : client_sku_master.description["category_code_l3"]),
                                              client_category_id: client_sku_master.client_category_id, brand: client_sku_master.brand, aisle_location: outbound_document_item_params["location"],
                                              client_category_name: client_sku_master.client_category.name, client_sku_master_id: client_sku_master.id,
                                              item_number: outbound_document_item_params["item_number"], outwarded_quantity: 0, status: gatepass_inventory_pending_receipt_status.original_code, 
                                              status_id: gatepass_inventory_pending_receipt_status.id, distribution_center_id: source.id, 
                                              client_id: outbound_document.client_id, user_id: outbound_document.user_id, details: {"own_label"=> client_sku_master.own_label },
                                              sku_eans: client_sku_master.sku_eans.collect(&:ean).flatten, imei_flag: (client_sku_master.try(:imei_flag).present? ? client_sku_master.try(:imei_flag) : "0"),
                                              serial_number_length: serial_number_length)
        success_item_count = success_item_count + 1
        # failure_items << { "itemnumber": outbound_document_item_params["item_number"].to_s, "errormsg": "null" }
      else
        failure_item_count = failure_item_count + 1

        concat_error_messages = "null"
        if error_code.present?
          error_string = []
          error_string << "Article" if (error_code.include?("01"))
          error_string << "Quantity" if (error_code.include?("03")) 
          error_string << "ScanInd" if (error_code.include?("04"))
          error_string << "Original Invoice" if (error_code.include?("05"))
          error_string << "DocumentNumber" if (error_code.include?("06")) 
          error_string << "DocumentType" if (error_code.include?("07"))
          error_string << "ReceivingVendor" if (error_code.include?("08")) 
          error_string << "SupplyingSite" if (error_code.include?("10"))
          error_string << "ItemNumber" if (error_code.include?("12"))
          if error_string.present?
            concat_error_messages = (error_string.join(",") + " " + "is missing")
            error_string = [concat_error_messages]
          end

          
          error_string << "Article is not present in Blubirch system"  if (error_code.include?("02"))
          error_string << "ReceivingVendor is not present in Blubirch system"  if (error_code.include?("09"))
          error_string << "SupplyingSite is not present in Blubirch system"  if (error_code.include?("11"))      
          concat_error_messages = error_string.join("|")
        end

        failure_items << { "itemnumber": outbound_document_item_params["item_number"].to_s, "errormsg": concat_error_messages }
      end      
    end

    if ((failure_item_count == 0) && outbound_document.valid?)
      if outbound_document.save
        if (success_item_error[:successmsg] == "null")
          success_item_error[:successmsg] = "DocumentNumber #{outbound_document.client_gatepass_number} is posted successfully."
        end
        success_items << success_item_error 
        failure_items << { "itemnumber": "null", "errormsg": "null" }
        document_hash = {"documentnumber": outbound_document.client_gatepass_number, "numberofitem": items_array.size.to_s, "successitemcount": success_item_count.to_s, "failureitemcount": failure_item_count.to_s, "failureitems": failure_items.flatten, "success": success_items.flatten}
        error_messages = document_hash
        return false, error_messages       
      else
        success_items << success_item_error
        success_item_count = 0
        document_hash = {"documentnumber": outbound_document.client_gatepass_number, "numberofitem": items_array.size.to_s, "successitemcount": success_item_count.to_s, "failureitemcount": failure_item_count.to_s, "failureitems": failure_items.flatten, "success": success_items.flatten}
        error_messages = document_hash
        return true, error_messages
      end
    elsif failure_item_count != 0
      success_items << success_item_error
      success_item_count = 0
      # failure_items.flat_map { |failure_item| failure_item[:errormsg] = "Not processed due to Master data issue in document" if failure_item[:errormsg] == "null" }
      document_hash = {"documentnumber": outbound_document.client_gatepass_number, "numberofitem": items_array.size.to_s, "successitemcount": success_item_count.to_s, "failureitemcount": failure_item_count.to_s, "failureitems": failure_items.flatten, "success": success_items.flatten}
      error_messages = document_hash
      return true, error_messages
    end
  end

  def self.generate_outbound_doc_report(user = nil, start_date = nil, end_date = nil, outbound_receiving_sites, outbound_supplying_sites)
    begin
      if outbound_receiving_sites.present? && outbound_supplying_sites.present?
        source_ids = DistributionCenter.where("code in (?)", outbound_supplying_sites).collect(&:id)
        destination_ids = DistributionCenter.where("code in (?)", outbound_receiving_sites).collect(&:id)
      elsif outbound_receiving_sites.present?
        destination_ids = DistributionCenter.where("code in (?)", outbound_receiving_sites).collect(&:id)
      elsif outbound_supplying_sites.present?
        source_ids = DistributionCenter.where("code in (?)", outbound_supplying_sites).collect(&:id)
      elsif user.present?
        source_ids = user.distribution_centers.pluck(:id) if user.present?
      end
      if source_ids.present? && destination_ids.present?        
        outbound_documents = OutboundDocument.includes(outbound_document_articles: [outbound_inventories: [:user]]).where("outbound_documents.is_forward = ? and outbound_documents.source_id in (?) and outbound_documents.destination_id in (?) and outbound_documents.document_submitted_time >= ? and outbound_documents.document_submitted_time <= ?", true, source_ids, destination_ids, Time.parse(start_date).beginning_of_day - 5.5.hours, Time.parse(end_date).end_of_day - 5.5.hours)
      elsif source_ids.present?
        outbound_documents = OutboundDocument.includes(outbound_document_articles: [outbound_inventories: [:user]]).where("outbound_documents.is_forward = ? and outbound_documents.source_id in (?) and outbound_documents.document_submitted_time >= ? and outbound_documents.document_submitted_time <= ?", true, source_ids, Time.parse(start_date).beginning_of_day - 5.5.hours, Time.parse(end_date).end_of_day - 5.5.hours)
      elsif destination_ids.present?
        outbound_documents = OutboundDocument.includes(outbound_document_articles: [outbound_inventories: [:user]]).where("outbound_documents.is_forward = ? and outbound_documents.destination_id in (?) and outbound_documents.document_submitted_time >= ? and outbound_documents.document_submitted_time <= ?", true, destination_ids, Time.parse(start_date).beginning_of_day - 5.5.hours, Time.parse(end_date).end_of_day - 5.5.hours)
      else        
        outbound_documents = OutboundDocument.includes(outbound_document_articles: [outbound_inventories: [:user]]).where("outbound_documents.is_forward = ? and outbound_documents.document_submitted_time >= ? and outbound_documents.document_submitted_time <= ?", true,Time.parse(start_date).beginning_of_day - 5.5.hours, Time.parse(end_date).end_of_day - 5.5.hours)
      end

      file_csv = CSV.generate do |csv|
        csv << ["Document Number", "Document Type", "Source Code", "Destination Code", "Assigned Username", "Status", "Item Number", "Article", "Article Description",
                "Merchandise Category","Scan Ind", "Expected Quantity", "Scan Quantity", "Short Quantity", "EAN", "Serial Number", "IMEI1", "IMEI2",
                "Short Reason", "User", "Scanning DateTme"]


        outbound_documents.each_with_index do |outbound_document, index|          
          source_code = outbound_document.source_code          
          if outbound_document.outbound_inventories.present? && outbound_document.outbound_document_articles.present?          
            outbound_document.outbound_document_articles.each do |outbound_document_article|
              outbound_document_article.outbound_inventories.each do |inventory|
                csv <<  [ outbound_document.client_gatepass_number, outbound_document.document_type, source_code, outbound_document.destination_code, outbound_document.try(:assigned_user).try(:username),
                          outbound_document.status, outbound_document_article.item_number, outbound_document_article.sku_code, outbound_document_article.item_description, outbound_document_article.merchandise_category, 
                          outbound_document_article.scan_id, outbound_document_article.quantity, inventory.quantity, inventory.short_quantity, inventory.details["ean"], 
                          inventory.serial_number, inventory.imei1, inventory.imei2, inventory.short_reason, inventory.try(:user).try(:username), inventory.try(:scanned_time)]
              end
            end
          end
        end
      end

      amazon_s3 = Aws::S3::Resource.new(region: Rails.application.credentials.aws_s3_region, access_key_id: Rails.application.credentials.access_key_id, secret_access_key: Rails.application.credentials.secret_access_key)

      bucket = Rails.application.credentials.aws_bucket

      time = Time.now.strftime("%F %H:%M:%S").to_s.tr('-', '')

      file_name = "outbound_report_#{time.parameterize.underscore}"

      obj = amazon_s3.bucket(bucket).object("uploads/outbound_documents/#{file_name}.csv")

      obj.put(body: file_csv, acl: 'public-read', content_disposition: 'attachment', content_type: 'text/csv')

      url = obj.public_url
      
      return url
    rescue Exception => message
      Rails.logger.warn("----------Error in generating outbound report #{message.inspect}")
    end

  end


end
