class Inventory < ApplicationRecord
    require 'csv'

    acts_as_paranoid
    belongs_to :distribution_center
    belongs_to :client
    belongs_to :user, optional: true
    belongs_to :gate_pass, optional: true
    belongs_to :gate_pass_inventory, optional: true
    belongs_to :client_category, optional: true
    belongs_to :inventory_status, class_name: "LookupValue", foreign_key: :status_id
    belongs_to :sub_location, optional: true
    belongs_to :pending_receipt_document_item, optional: true

    has_one :return_inventory, dependent: :destroy
    has_many :inventory_grading_details
    has_one :inventory_grading_detail, -> { where(is_active: true) }
    has_many :inventory_statuses
    has_many :alert_inventories
    has_one :packed_inventory
    has_one :brand_call_log, -> { where(is_active: true) }
    has_one :vendor_return, -> { where(is_active: true) }
    has_one :replacement, -> { where(is_active: true) }
    has_one :insurance, -> { where(is_active: true) }
    has_one :repair, -> { where(is_active: true) }
    has_one :redeploy, -> { where(is_active: true) }
    has_one :liquidation, -> { where(is_active: true) }
    has_one :markdown, -> { where(is_active: true) }
    has_one :e_waste, -> { where(is_active: true) }
    has_one :pending_disposition, -> { where(is_active: true) }
    has_one :capital_asset, -> { where(is_active: true) }
    has_one :rental, -> { where(is_active: true) }
    has_one :cannibalization, -> { where(is_active: true) }
    has_many :third_party_claims
    has_many :request_items
    has_many :put_requests, through: :request_items

    #has many relation
    has_many :brand_call_logs
    has_many :vendor_returns
    has_many :replacements
    has_many :insurances
    has_many :repairs
    has_many :redeploys
    has_many :restocks
    has_many :liquidations
    has_many :markdowns
    has_many :e_wastes
    has_many :pending_dispositions
    has_many :warehouse_order_items#, as: :inventory
    has_many :inventory_information
    has_many :inventory_documents
    has_many :attachments, as: :attachable
    has_many :ecom_liquidations
    has_many :saleables
    has_many :capital_assets
    has_many :rentals
    has_many :cannibalizations

    include Filterable
    include JsonUpdateable
    include AssociatedRecordsUpdateable
    
    # before_create :check_sub_locations
    # validates_uniqueness_of :tag_number, :case_sensitive => false, allow_blank: true
    validates_length_of :tag_number, minimum: 5
    scope :filter_by_tag_number, -> (tag_number) { where("tag_number ilike ?", "%#{tag_number}%")}
    scope :opened, -> { where.not(status: "Closed Successfully") }
    scope :not_inwarded, -> { where(is_putaway_inwarded: false) }

    STATUS_LOOKUP_KEY_NAMES = {"Brand Call-Log" => "BRAND_CALL_LOG_STATUS", "RTV" => "VENDOR_RETURN_STATUS", "Insurance" => "INSURANCE_STATUS","Pending Disposition"=> "PENDING_DISPOSITION_STATUS","Repair" => "REPAIR_STATUS","Replacement" => "REPLACEMENT_STATUS","Restock" => "RESTOCK_STATUS","Pending Transfer Out" => "MARKDOWN_STATUS" ,"Liquidation" => "LIQUIDATION_STATUS",  "E-Waste" => "E-WASTE_STATUS", "Cannibalization" => "CANNIBALIZATION_STATUS" }

    def update_inward_putaway!
      if self.distribution_center.sub_locations.present?
        self.update(is_putaway_inwarded: false)
      else
        self.update(is_putaway_inwarded: nil)
      end
    end
    
    def putaway_inwarded?
      self.is_putaway_inwarded == false ? false : true
    end
    
    def self.create_sbd_inventories
        inventories_array = [{invoice_number: 7123345, customer_return_reason: "Quality Issue", grading_required: true, sku_code: ["Power-7727","Power-7779","Power-7814","Power-7829","Power-7900","Power-7915"], disposition: "Send to Factory"},
                                                 {invoice_number: 7123345, customer_return_reason: "Transporter Issue", grading_required: false, sku_code: ["Power-7728","Power-7780","Power-7815","Power-7830","Power-7901","Power-7916"], disposition: "Send to Warehouse"}]
        inventory_pending_approval_status = LookupValue.where(code: "inv_sts_store_pending_approval").first
        return_request_store_pending = LookupValue.where(code: Rails.application.credentials.return_request_pending_store_approval).first
        grade_array = ["inv_grade_new", "inv_grade_open_box", "inv_grade_very_good", "inv_grade_good", "inv_grade_defective", "inv_grade_not_tested"]
        ActiveRecord::Base.transaction do
            inventories_array.each do |inventory_array|
                return_request_number = "R-#{SecureRandom.hex(3)}"
                total_inventories = 0
                customer_return_reason = CustomerReturnReason.where(name: inventory_array[:customer_return_reason]).first
                if inventory_array[:grading_required] == true
                    invoice = Invoice.where(invoice_number: inventory_array[:invoice_number]).first
                    tag_number = "T-#{SecureRandom.hex(3)}"
                    client_sku_masters = ClientSkuMaster.where("code in (?)", inventory_array[:sku_code])
                    invoice_inventory_details = invoice.invoice_inventory_details.where("client_sku_master_id in (?)", client_sku_masters.collect(&:id))

                    invoice_inventory_details.each do |invoice_inventory_detail|
                        grade = LookupValue.where(code: grade_array.sample).first
                        quantity = ((invoice_inventory_detail.quantity - 1) == 0) ? 1 : 1
                        total_inventories = total_inventories + quantity

                        json_details = {"return_request_number" => return_request_number, "quantity" => quantity,
                                                        "item_price" => invoice_inventory_detail.item_price, "client_category_id" => invoice_inventory_detail.client_category_id,
                                                        "client_sku_master_id" => invoice_inventory_detail.client_sku_master_id, "customer_return_reason" => inventory_array[:customer_return_reason], customer_return_reason_id: customer_return_reason.try(:id),
                                                        "invoice_id" => invoice.try(:id),"invoice_number" => invoice.invoice_number, "sku" => invoice_inventory_detail.try(:client_sku_master).try(:code),
                                                        "packaging_status" => "Not Packed", "status" => inventory_pending_approval_status.try(:original_code), "grade" => grade.try(:original_code)}


                        inventory = Inventory.new(tag_number: tag_number, details: json_details.merge!(invoice_inventory_detail.details),
                                                                            distribution_center_id: invoice.distribution_center_id, client_id: invoice.client_id, user_id: User.first.id, is_putaway_inwarded: false)
                        
                        inventory.inventory_statuses.build(status_id: inventory_pending_approval_status.try(:id), distribution_center_id: invoice.distribution_center_id, details: invoice_inventory_detail.details, is_active: true, user_id: User.first.id)
                        inventory.inventory_grading_details.build(grade_id: grade.try(:id), distribution_center_id: invoice.distribution_center_id, details: invoice_inventory_detail.details, is_active: true, user_id: User.first.id)
                        if inventory.save
                            invoice_inventory_detail.update(return_quantity: (invoice_inventory_detail.return_quantity + quantity))
                        end
                    end

                    return_request_details = {"total_inventories" => total_inventories, "invoice_number" => inventory_array[:invoice_number],
                                                                        "customer_return_reason" => inventory_array[:customer_return_reason], "destination" => invoice.try(:client).try(:address)}
                    ReturnRequest.create!(request_number: return_request_number, details: return_request_details, status_id: return_request_store_pending.try(:id),
                                                              distribution_center_id: invoice.distribution_center_id, client_id: invoice.client_id, invoice: invoice, customer_return_reason: customer_return_reason)
                else
                    invoice = Invoice.where(invoice_number: inventory_array[:invoice_number]).first
                    client_sku_masters = ClientSkuMaster.where("code in (?)", inventory_array[:sku_code])
                    invoice_inventory_details = InvoiceInventoryDetail.where("client_sku_master_id in (?)", client_sku_masters.collect(&:id))
                    
                    invoice_inventory_details.each do |invoice_inventory_detail|
                        grade = LookupValue.where(code: grade_array.sample).first
                        quantity = ((invoice_inventory_detail.quantity - 2) == 0) ? 1 : 2
                        total_inventories = total_inventories + quantity

                        json_details = {"return_request_number" => return_request_number, "quantity" => quantity,
                                        "item_price" => invoice_inventory_detail.item_price, "client_category_id" => invoice_inventory_detail.client_category_id,
                                        "client_sku_master_id" => invoice_inventory_detail.client_sku_master_id, "customer_return_reason" => inventory_array[:customer_return_reason], customer_return_reason_id: customer_return_reason.try(:id),
                                        "invoice_number" => invoice_inventory_detail.invoice.invoice_number, "sku" => invoice_inventory_detail.try(:client_sku_master).try(:code),
                                        "packaging_status" => "Not Packed", "status" => inventory_pending_approval_status.try(:original_code), "grade" => grade.try(:original_code)}
                        
                        inventory = Inventory.new(tag_number: tag_number, details: json_details.merge!(invoice_inventory_detail.details),
                                                                            distribution_center_id: invoice.distribution_center_id, client_id: invoice.client_id, user_id: User.first.id, is_putaway_inwarded: false)
                        
                        inventory.inventory_statuses.build(status_id: inventory_pending_approval_status.try(:id), distribution_center_id: invoice.distribution_center_id, details: invoice_inventory_detail.details, is_active: true, user_id: User.first.id)
                        inventory.inventory_grading_details.build(grade_id: grade.try(:id), distribution_center_id: invoice.distribution_center_id, details: invoice_inventory_detail.details, is_active: true, user_id: User.first.id)
                        if inventory.save
                            invoice_inventory_detail.update(return_quantity: (invoice_inventory_detail.return_quantity + quantity))
                        end
                    end
                    return_request_details = {"total_inventories" => total_inventories, "invoice_number" => inventory_array[:invoice_number],
                                                                        "customer_return_reason" => inventory_array[:customer_return_reason], "destination" => invoice.try(:client).try(:address)}
                    ReturnRequest.create!(request_number: return_request_number, details: return_request_details, status_id: return_request_store_pending.try(:id),
                                                             distribution_center_id: invoice.distribution_center_id, client_id: invoice.client_id, invoice: invoice, customer_return_reason: customer_return_reason)
                end
            end
        end
    end

    def self.approve_inventories
        pending_packaging_status = LookupValue.where(code: Rails.application.credentials.inventory_status_store_pending_packaging).first
        return_request_client_pending = LookupValue.where(code: Rails.application.credentials.return_request_pending_packaging).first
        return_requests = ReturnRequest.all
        return_requests.each do |return_request|
          inventories = Inventory.where("details ->> 'return_request_number' = ?", return_request.request_number)
          inventories.each do |inventory|
              last_inventory_status = inventory.inventory_statuses.where(is_active: true).last
              new_inventory_status = last_inventory_status.dup
              new_inventory_status.status_id = pending_packaging_status.try(:id)
              new_inventory_status.is_active = true
              if new_inventory_status.save
                last_inventory_status.update(is_active: false)
                inventory.update(details: inventory.merge_details({"status" => pending_packaging_status.try(:original_code)}))
              end
          end
          return_request.update(status_id: return_request_client_pending.try(:id), details: return_request.merge_details({"approved_time" => Time.now.to_s, "approval_sent_date" => Time.now.to_s}))
        end
    end

    def self.pending_packaging
        distribution_center = DistributionCenter.where(name: "Ramji Tools").first
        user = User.first
        box_inventory_mappings = [{box_number: "BX_471", sku_code: ["Power-7727","Power-7779","Power-7814","Power-7829","Power-7900","Power-7915"]},
                                                         {box_number: "BX_471", sku_code: ["Power-7728","Power-7780","Power-7815","Power-7830","Power-7901","Power-7916"]}]
        box_inventory_mappings.each do |box_inventory_mapping|
            packaging_box = PackagingBox.find_or_create_by(box_number: box_inventory_mapping[:box_number], distribution_center: distribution_center, user: user)
            box_inventory_mapping[:sku_code].each do |sku|
                inventory = Inventory.where("details ->> 'sku' = ?", sku).first
                if inventory.present?
                    PackedInventory.create(packaging_box: packaging_box, inventory: inventory)
                    inventory.packed_inventories
                end
            end
        end     
    end

    def self.create_rtv_qa_records
      file = Roo::Excelx.new("#{Rails.root}/public/sample_files/RTV_DataSet_11_07_2020.xlsx").sheet(1)
      warehouse_distribution_center_id = LookupValue.where("code = ?", Rails.application.credentials.distribution_center_types_warehouse).first.try(:id)
      distribution_center = DistributionCenter.where(distribution_center_type_id: warehouse_distribution_center_id).first
      headers = file.row(1)
      (2..file.last_row).each do |ind|
        values = file.row(ind)
        ActiveRecord::Base.transaction do
          inventory = Inventory.new
          inventory.tag_number = values[20]
          inventory.distribution_center_id = distribution_center.try(:id)
          inventory.client_id = Client.first.id
          inventory.user_id = Client.first.id
          inventory.details = {}
          inventory.details['brand_id'] = values[8]
          inventory.details['invoice_number'] = values[0]
          inventory.details['invoice_date'] = values[12]
          inventory.details['inward_date'] = values[13]
          inventory.details['return_request_created_date'] = values[14]
          inventory.disposition = values[26]
          inventory.return_reason = values[27]
          inventory.item_description = values[28]
          inventory.details['packaging_status'] = 'Pending Picking'
          inventory.details['pick'] = false
          inventory.sku_code = values[29]
          inventory.details['return_request_number'] = values[30]
          inventory.quantity = values[31]
          inventory.details['return_quantity'] = values[32]
          inventory.item_price = values[33]
          inventory.grade = values[34]
          inventory.is_putaway_inwarded = false
          if inventory.save
            VendorReturn.create_record(inventory)
          end
        end
      end
    end

    def self.export(disposition_center_ids)
      status =  LookupValue.where("code = ?", Rails.application.credentials.inventory_status_warehouse_pending_issue_resolution).first
      @inventories = Inventory.where(distribution_center_id: disposition_center_ids, status_id: status.id).where("details ->> 'grn_number' is NULL").order('updated_at desc').select {|i| i.details['issue_type'] == "In-Transit"}

      file_csv = CSV.generate do |csv|
        csv << ["Source Site", "RP Site", "OBD Number", "OBD Date", "Ageing", "Tag id", "Article id", "Article Description", "Status"]
        @inventories.each do |inventory|
          ageing = " #{(Date.today.to_date - (inventory.created_at.to_date rescue 0)).to_i} days" rescue "0 days"
          csv << [(inventory.gate_pass.source_code rescue 'N/A'), inventory.distribution_center.code, (inventory.gate_pass.client_gatepass_number rescue 'N/A'), (inventory.gate_pass.dispatch_date.strftime("%d/%b/%Y")  rescue 'N/A'), ageing, inventory.tag_number, inventory.sku_code, inventory.item_description, inventory.status]
        end
      end

      amazon_s3 = Aws::S3::Resource.new(region: Rails.application.credentials.aws_s3_region, access_key_id: Rails.application.credentials.access_key_id, secret_access_key: Rails.application.credentials.secret_access_key)

      bucket = Rails.application.credentials.aws_bucket

      time = Time.now.strftime("%F %H:%M:%S").to_s.tr('-', '')

      file_name = "real_time_grn_report_#{time.parameterize.underscore}"

      obj = amazon_s3.bucket(bucket).object("uploads/real_time_grn_reports/#{file_name}.csv")

      obj.put(body: file_csv, acl: 'public-read', content_disposition: 'attachment', content_type: 'text/csv')

      url = obj.public_url
      
      return url
    end

    def get_current_bucket
      inventory = self
      case inventory.disposition
      when "Brand Call-Log"
        i =  inventory.brand_call_log.present? ? inventory.brand_call_log : inventory.brand_call_logs.order("updated_at").last
        return i
      when "Insurance"
        i = inventory.insurance.present? ? inventory.insurance : inventory.insurances.order("updated_at").last
        return i
      when "Replacement"
        i = inventory.replacement.present? ? inventory.replacement : inventory.replacements.order("updated_at").last
        return i
      when "Repair"
        i = inventory.repair.present? ? inventory.repair : inventory.repairs.order("updated_at").last
        return i
      when "Liquidation"
        i = inventory.liquidation.present? ? inventory.liquidation : inventory.liquidations.order("updated_at").last
        return i
      when "Redeploy"
        i = inventory.redeploy.present? ? inventory.redeploy : inventory.redeploys.order("updated_at").last
        return i
      when "Restock"
        i = inventory.restocks.order("updated_at").last
        return i  
      when "Pending Transfer Out", "Markdown"
        i = inventory.markdown.present? ? inventory.markdown : inventory.markdowns.order("updated_at").last
        return i
      when "E-Waste"
        i = inventory.e_waste.present? ? inventory.e_waste : inventory.e_wastes.order("updated_at").last
        return i
      when "RTV"
        i =  inventory.vendor_return.present? ? inventory.vendor_return : inventory.vendor_returns.order("updated_at").last
        return i
      when "Pending Disposition"
        i =  inventory.pending_disposition.present? ? inventory.pending_disposition : inventory.pending_dispositions.order("updated_at").last
        return i
      when "Dispatch"
        i =  inventory.warehouse_order_items.order("updated_at").last
        return i
      when "Saleable"
        i =  inventory.saleables.order("updated_at").last
        return i
      end
    end

    def self.generate_and_send_inward_report_daily
      time = Time.now.in_time_zone('Mumbai').strftime("%d/%b/%Y - %I:%M %p")
      inward_report_url = Inventory.export_inward_visibility_report
      ReportMailer.send_daily_reports(inward_report_url, 'Inward', time ).deliver_now
    end

    def self.generate_and_send_outward_report_daily
      time = Time.now.in_time_zone('Mumbai').strftime("%d/%b/%Y - %I:%M %p")
      outward_report_url = Inventory.export_outward_visibility_report
      ReportMailer.send_daily_reports(outward_report_url, 'Outward', time).deliver_now
    end

    def self.generate_monthly_timeline_report
      time = Time.now.in_time_zone('Mumbai').strftime("%d/%b/%Y - %I:%M %p")
      start_date = Date.new(Time.now.year, 4, 1).in_time_zone('Mumbai').beginning_of_month.strftime("%Y-%m-%d")
      end_date = (Date.today.in_time_zone('Mumbai').end_of_day - 1.day).strftime("%Y-%m-%d")
      timeline_report_url = Inventory.timeline_report(nil, 'monthly')
      ReportMailer.send_monthly_timeline_report(timeline_report_url, 'Monthly Inward Report', time).deliver_now
    end

    def self.generate_daily_timeline_report
      time = Time.now.in_time_zone('Mumbai').strftime("%d/%b/%Y - %I:%M %p")
      start_date = Date.today.at_beginning_of_month.in_time_zone('Mumbai').strftime("%Y-%m-%d")
      end_date = (Date.today.in_time_zone('Mumbai').end_of_day).strftime("%Y-%m-%d")
      timeline_report_url = Inventory.timeline_report
      ReportMailer.send_daily_timeline_report(timeline_report_url, 'Daily Inward Report', time).deliver_now
    end

    #& Inventory.export_sync_dashboard_report(type: :current_data/:all_data, start_date)
    #^ URL - https://bb-dashboard-feeder.s3.ap-south-1.amazonaws.com/dashboard_data.csv
    def self.export_sync_dashboard_report(type: :current_data, start_date: Date.current, end_date: Date.current)
      cordinates_hash = Inventory.get_location_cordinates
      file_csv = CSV.generate do |csv|
        csv << [
          "tag_number",
          "date", 
          "quantity",
          "Disposition",
          "Grade",
          "Return Reason",
          "Unitprice",
          "Recovered",
          "Status",
          "Process Status",
          "Processed",
          "Generated",
          "Channel",
          "Brand",
          "own_label",
          "Site Name",
          "Category_l1",
          "Category_l2",
          "Category_l3",
          "Source Code",
          "latitude",
          "longitude",
          "State",
          "City",
          "dispatch_date",
          "inward_user_id",
          "Destination Code",
          "grader_name",
          "inwarding_disposition",
          "Actual Tat",
          "Tat Status",
          "Expected Tat",
          "Return Type"
        ]
        distribution_center_with_city_code_hash = {}
        if type == :current_data
          query = ["DATE(inventories.updated_at) = ? OR DATE(inventories.created_at) = ? ", start_date.to_date, end_date.to_date]
        else
          query = ["DATE(inventories.created_at) BETWEEN  ? AND  ? ", start_date.to_date, end_date.to_date]
        end
        inventories = Inventory.includes(:distribution_center).where(query).order("inventories.created_at asc").select(
          :tag_number,
          :created_at,
          :updated_at,
          :distribution_center_id,
          :quantity,
          :disposition,
          :grade,
          :return_reason,
          :item_price,
          :status,
          :details
        )
        distribution_center_ids = inventories.pluck(:distribution_center_id).compact.uniq
        DistributionCenter.includes(:city).where(id: distribution_center_ids).select(:id, :city_id).each { |d| distribution_center_with_city_code_hash[d.id] = d&.city&.original_code }
        
        inventories.each do |inventory|
          tat = (inventory.updated_at.to_date - inventory.created_at.to_date).to_i
          tat_status = (tat > 10) ? 'Beyond TAT' : 'Within TAT'
          state, latitude, longitude = cordinates_hash["#{(distribution_center_with_city_code_hash[inventory.distribution_center_id] rescue '')}"]
          process_status = ((inventory.status == "Closed Successfully" || inventory.status == "") ? "Processed" : "Generated")
          csv << [
            inventory.tag_number,
            inventory.created_at.to_date.to_s(:p_date3),
            inventory.quantity,
            inventory.disposition,
            inventory.grade,
            inventory.return_reason,
            inventory.item_price, #! MRP 
            inventory.item_price, #! Recovered Amount
            inventory.status,
            process_status, #! Process Status ? Processed : Generated
            process_status ==  "Processed" ? 1 : 0,
            process_status ==  "Generated" ? 1 : 0,
            'Offline', #! Channel for time being
            (inventory.details['brand'].blank? ? 'Others' : inventory.details['brand']),
            (inventory.details["own_label"] == true ? "OL" : "Non OL"), #! Own Label
            inventory.details['site_name'],
            inventory.details['category_l1'],
            inventory.details['category_l2'],
            inventory.details['category_l3'],
            inventory.details['source_code'],
            latitude,
            longitude,
            state, #! State
            (distribution_center_with_city_code_hash[inventory.distribution_center_id] rescue ''), #! City
            inventory.updated_at.to_date,
            inventory.details['inward_user_id'],
            inventory.details['destination_code'],
            inventory.details['inward_user_name'],
            inventory.details['inwarding_disposition'],
            tat,
            tat_status,
            tat,
            'internal' #! Static
          ]
        end
      end
      amazon_s3 = Aws::S3::Resource.new(region: Rails.application.credentials.aws_s3_region, access_key_id: Rails.application.credentials.access_key_id, secret_access_key: Rails.application.credentials.secret_access_key)

      bucket = Rails.application.credentials.dashboard_aws_bucket
      #bucket = Rails.application.credentials.aws_bucket
      file_path = type == :current_data ? "RIMS_Data/Rims_staging_data.csv" : "RIMS_Data/Rims_master_data.csv"

      time = Time.now.strftime("%F %H:%M:%S").to_s.tr('-', '')

      obj = amazon_s3.bucket(bucket).object(file_path)

      obj.put(body: file_csv, acl: 'public-read', content_disposition: 'attachment', content_type: 'text/csv')

      url = obj.public_url
      return url
    end

    #Inventory.get_location_cordinates
    def self.get_location_cordinates      
      Rails.cache.fetch("cache_localion_cordinates_redis", expires_in: 1.hour) do
        hash = {}
        file = File.new("#{Rails.root}/public/master_files/coordinates.csv") if file.nil?
        CSV.foreach(file.path, headers: true) do |row|
          hash["#{row['city']}"] = [row['state'], row['Latitude'], row['Longitude']]		  
        end
        hash
      end
    end

    def self.export_inward_visibility_report(user = nil)
      begin
        distribution_centers_ids = user.distribution_centers.pluck(:id) if user.present?
        inventory_status_warehouse_pending_grn = LookupValue.where("code = ?", Rails.application.credentials.inventory_status_warehouse_pending_grn).first
        if user.present? && !user.roles.pluck(:code).include?(:central_admin)
          # inventories = Inventory.includes(:distribution_center, :inventory_grading_details, :inventory_statuses, :inventory_documents, :gate_pass, :gate_pass_inventory, :vendor_return, :replacement, :insurance, :repair, :redeploy, :liquidation, :markdown, :e_waste, :pending_disposition).opened.where("distribution_center_id in (?) and status_id != ? and is_forward = ?", distribution_centers_ids, inventory_status_warehouse_pending_grn.try(:id), false).order("(details ->> 'grn_received_time')::timestamptz ASC")
          inventories = Inventory.includes(:inventory_grading_detail, :inventory_statuses, :inventory_documents, :gate_pass, :gate_pass_inventory, :vendor_return, :replacement, :insurance, :repair, :redeploy, :liquidation, :markdown, :e_waste, :pending_disposition, :vendor_returns, :replacements, :insurances, :repairs, :redeploys, :liquidations, :markdowns, :e_wastes, :pending_dispositions, distribution_center: [:city]).opened.where("distribution_center_id in (?) and status_id != ? and is_forward = ?", distribution_centers_ids, inventory_status_warehouse_pending_grn.try(:id), false).order("(inventories.details ->> 'grn_received_time')::timestamptz ASC")
        else
          # inventories = Inventory.includes(:inventory_grading_details, :inventory_statuses, :inventory_documents, :gate_pass, :gate_pass_inventory, :vendor_return, :replacement, :insurance, :repair, :redeploy, :liquidation, :markdown, :e_waste, :pending_disposition).opened.where("status_id != ? and is_forward = ?", inventory_status_warehouse_pending_grn.try(:id), false).order("(details ->> 'grn_received_time')::timestamptz ASC")
          inventories = Inventory.includes(:inventory_grading_detail, :inventory_grading_details, :inventory_statuses, :inventory_documents, :gate_pass, :gate_pass_inventory, :vendor_return, :replacement, :insurance, :repair, :redeploy, :liquidation, :markdown, :e_waste, :pending_disposition, :vendor_returns, :replacements, :insurances, :repairs, :redeploys, :liquidations, :markdowns, :e_wastes, :pending_dispositions, distribution_center: [:city]).opened.where("inventories.status_id != ? and inventories.is_forward = ?", inventory_status_warehouse_pending_grn.try(:id), false).order("(inventories.details ->> 'grn_received_time')::timestamptz ASC")
        end

        if Rails.env == 'development'
          start_date = Date.today.beginning_of_month
          end_date = Date.today.end_of_month
          inventories = inventories.where(created_at: start_date..end_date)
        end
        file_types = LookupKey.where(code: "RETURN_REASON_FILE_TYPES").last
        invoice_file_type = file_types.lookup_values.where(original_code: "Customer Invoice").last
        nrgp_file_type = file_types.lookup_values.where(original_code: "NRGP").last
        inventory_closed_status = LookupValue.where(code: Rails.application.credentials.inventory_status_warehouse_closed_successfully).last

        file_csv = CSV.generate do |csv|
          csv << ["Sl No", "RPA Site Code", "RPA Site Name", "Store Site Code", "Store Site Name", "Inward Scan ID", "Group Description", "Category Description", "Class Description", "Brand Type", "Item Code", "Item description", "Brand", "Serial Number", "Serial Number 2", "Qty", "MAP",
                  "OBD Number", "OBD Date", "GRN Number", "GRN Date", "customer use (YES/NO)", "Grade",
                  "As per Check list Reason for RPA Inward", "Item Condition as per Grading @RPA", "Physical defect", "Physical defect position", "Accessories Available  Yes/No", "Outer Carton box Condition", "Functional Condition", "Customer Invoice #", "Work Order number mentioned on Checklist",  
                  "RPA Call log/Insurance claim /OL category/NER number", "Call log/insurance claim date",
                  "Visit date-Engineer/Surveyor", "Resolution Date",  "RPA pending Status", 
                  "Pending Ageing from GRN date", "Bucket Ageing", "Alert Status", "Created At", "Lot Id", "Sub-Location Name", "Sub-Location ID"]
          inventories.each_with_index do |inventory, index|
            
            if inventory.serial_number.present?
              serial_number = inventory.serial_number.scan(/\D/).empty? ? "'" + inventory.serial_number :  inventory.serial_number
            else
              serial_number = ""
            end

            if inventory.serial_number_2.present?
              serial_number_2 = inventory.serial_number_2.scan(/\D/).empty? ? "'" + inventory.serial_number_2 :  inventory.serial_number_2
            else
              serial_number_2 = ""
            end

            if inventory.sr_number.present?
              sr_number = inventory.sr_number.scan(/\D/).empty? ? "'" + inventory.sr_number :  inventory.sr_number
            else
              sr_number = ""
            end

            if ["Brand Approved DOA", "1) Brand Approved DOA"].include?(inventory.return_reason)
              remark = "Not eligible for testing / Not required"
              physical_remark = "NA"
            else
              remark = inventory.remarks
              physical_remark = inventory.physical_remark_old.present? ? inventory.physical_remark_old : inventory.physical_remark
            end

            if inventory.status_id == inventory_closed_status.id
              dispatch_date = inventory.inventory_statuses.last.created_at.to_date.strftime("%d/%b/%Y") rescue ""
            else
              dispatch_date = ''
            end
            # city = inventory.details["site_name"] rescue ""
            city = inventory.try(:distribution_center).try(:city).try(:original_code) rescue ""
            category_l1 = inventory.details["category_l1"] rescue ""
            category_l2 = inventory.details["category_l2"] rescue ""
            category_l3 = inventory.details["category_l3"] rescue ""
            used = inventory.details["processed_grading_result"]["Item Condition"] rescue ''
            value = used.try(:strip).try(:downcase)
            if used.present?
              if (value == "Un-used".downcase) || (value == "Unused".downcase)
                used = "NO"
              elsif (value == "Used".downcase) || (value == "Minor Used".downcase) || (value == "Major Used".downcase) || (value == "Complete damage".downcase)
                used = "YES"
              else
                used = used
              end
            else
              "NA"
            end
            accessories = inventory.details["processed_grading_result"]["Accessories"] rescue ''
            box_condition = (inventory.details["processed_grading_result"]["Packaging"].present? ? inventory.details["processed_grading_result"]["Packaging"] :  inventory.details["processed_grading_result"]["Packaging Condition"]) rescue ''
            
            # pending_aging_from_grn = TimeDifference.between(inventory.details["grn_received_time"].to_date.strftime("%d/%b/%Y") , Time.now.to_s).in_days.ceil if inventory.details["grn_received_time"].present?
            
            physical_condition = ""
            physical_condition_positions = ""
            physical_condition_hash = inventory.inventory_grading_detail.details["final_grading_result"]["Physical Condition"] rescue ""
            if physical_condition_hash.present?
              physical_condition_hash.each_with_index do |physical_condition_val, i|
                if physical_condition_val["test"].include? "Position"
                  unless physical_condition_val["value"].include?('NA')
                    physical_condition_positions += "/" unless physical_condition_positions.blank?
                    physical_condition_positions += physical_condition_val["value"]
                  end
                else
                  unless physical_condition_val["value"].include? "No" 
                    physical_condition += "/" unless physical_condition.blank?
                    physical_condition += physical_condition_val["value"]
                  end
                end
              end
              physical_condition = "No Physical Defect" if physical_condition.blank?
              physical_condition_positions = "NA" if physical_condition_positions.blank?
            elsif (inventory.inventory_grading_detail.details["final_grading_result"]["Physical"] rescue '').present?
              physical_condition_positions = "NA"
              physical_condition = inventory.physical_remark_old
            else
              physical_condition = "NA"
              physical_condition_positions = "NA"
            end

            pending_aging_from_grn = "#{(Date.today.to_date - inventory.details["grn_received_time"].to_date).to_i}" rescue "0"

            doc = inventory.inventory_documents.where(document_name_id: invoice_file_type.id).last
            if doc.present?
              invoice_ref = doc.reference_number
            elsif inventory.details['invoice_number'].present?
              invoice_ref = inventory.details['invoice_number']
            elsif inventory.details["document_text"].present?
              invoice_ref = inventory.details["document_text"]
            else
              invoice_ref = ''
            end
            
            nrgp = inventory.inventory_documents.where(document_name_id: nrgp_file_type.id).last
            nrgp_ref = nrgp.present? ? nrgp.reference_number : ""    

            if inventory.details["own_label"] == true
              brand_type = "OL"          
            else
              brand_type = "Non OL"
            end
            
            bucket = inventory.get_current_bucket
            
            call_log = ''
            call_log_or_claim_date = ''
            resolution_date = ''
            visit_date = ""
            if bucket.present?
              status = inventory.get_status(bucket) rescue ''
              alert_status = bucket.details["criticality"] rescue ""
              bucket_ageing = "#{(Date.today.to_date - bucket.created_at.to_date).to_i}" rescue "0"
            else
              status = inventory.status rescue ''
            end

            vr =  inventory.vendor_return
            vr = inventory.vendor_returns.where.not(call_log_id: nil).last if vr.blank?
            insurance = inventory.insurance
            insurance = inventory.insurances.where.not(call_log_id: nil).last if insurance.blank?
            rep = inventory.replacement
            rep = inventory.replacements.where.not(call_log_id: nil).last if rep.blank?

            if vr.present?
              call_log = vr.call_log_id if call_log.blank?
              call_log_or_claim_date = vr.call_log_or_claim_date if call_log_or_claim_date.blank?
              resolution_date = vr.resolution_date_time.present? ? vr.resolution_date_time : vr.updated_at.to_date.strftime("%d/%b/%Y")
              visit_date = vr.brand_inspection_date.to_date.strftime("%d/%b/%Y") rescue ''
            elsif insurance.present?
              call_log = insurance.call_log_id if call_log.blank?
              call_log_or_claim_date = insurance.call_log_or_claim_date if call_log_or_claim_date.blank?
              resolution_date = insurance.resolution_date_time.present? ? insurance.resolution_date_time : insurance.updated_at.to_date.strftime("%d/%b/%Y")
            elsif rep.present?
              call_log = rep.call_log_id if call_log.blank?
              call_log_or_claim_date = rep.call_log_or_claim_date if call_log_or_claim_date.blank?
              resolution_date = rep.resolution_date_time.present? ? rep.resolution_date_time : rep.updated_at.to_date.strftime("%d/%b/%Y")
            end

            if call_log.blank? && inventory.details['return_reason_document_type'] == 'ner_number'
              call_log = inventory.details['document_text']
            end

            inventory_grading_detail = inventory.inventory_grading_detail
            orientation_arr = []
            orientation_hash = {}
            final_hash = {}
            str = ""
            final_grading_result = inventory_grading_detail.details["final_grading_result"] rescue {}
            if final_grading_result.present?
              final_grading_result.each do |k,v|
                v.each do |v1|
                  next unless v1['annotations']
                  v1["annotations"].each do |v2|
                    if v2["orientation"] != "Pack" && v2["text"] != "NA"
                      orientation_arr << (v2["orientation"] + " " + v2["text"]) rescue nil
                    end
                  end
                end
              end
              orientation_arr.compact.each do |value|
                if value.present?
                  if orientation_hash[value].present?
                    orientation_hash[value] = orientation_hash[value] + 1
                  else
                    orientation_hash[value] = 1
                  end 
                end
              end
              processed_grading_result = inventory.details["processed_grading_result"]
              orientation_hash.each do |key,value|
                str = str + "#{key} (#{value})\n"
              end
              if orientation_hash.present?
                final_hash["Physical"] = str
              else
                final_hash["Physical"] = processed_grading_result["Physical"] rescue ""
              end
            end
            
            if inventory.sub_location.present?
              sub_location_name = inventory.sub_location&.name
              sub_location_code = inventory.sub_location&.code
            elsif inventory.is_putaway_inwarded == false && inventory.details["issue_type"].nil?
              sub_location_name = sub_location_code = "Pending Inward Putaway"
            else
              sub_location_name = sub_location_code = "NA"
            end

            rpa_site_name = inventory.try(:distribution_center).try(:name) rescue nil
            store_site_name = DistributionCenter.where(code: inventory.details["source_code"]).last.name rescue nil
            item_condition = (inventory.details["processed_grading_result"].present? ? inventory.details["processed_grading_result"].except('Reason','Functional','Packaging' ,'Accessories','Physical').merge(final_hash).collect {|k| "#{k[0]}: #{k[1]}\n"}.join("") : '')
            item_condition = item_condition.remove("Item Condition: ").split("\n")[1]
            csv << [(index + 1),inventory.details["destination_code"], rpa_site_name, inventory.details["source_code"], store_site_name, inventory.tag_number, category_l1, category_l2, category_l3, brand_type, inventory.sku_code,
                    inventory.item_description, inventory.details["brand"], serial_number, serial_number_2, inventory.quantity, inventory.item_price,
                    inventory.gate_pass&.client_gatepass_number, (inventory.details["dispatch_date"].to_date.strftime("%d/%b/%Y") rescue ''),
                    inventory.details["grn_number"], (inventory.details["grn_received_time"].to_date.strftime("%d/%b/%Y") rescue ''), used, inventory.grade, inventory.return_reason, remark, physical_condition, physical_condition_positions, 
                    accessories, box_condition, (inventory.details["processed_grading_result"].present? ? inventory.details["processed_grading_result"].extract!('Functional').collect {|k| "#{k[0]}: #{k[1]}\n"}.join("") : ''), invoice_ref, sr_number, call_log, call_log_or_claim_date, visit_date, resolution_date, status, 
                    pending_aging_from_grn, bucket_ageing, alert_status, inventory.created_at.to_date.strftime("%d/%b/%Y"), inventory.order_id, sub_location_name, sub_location_code]
          end
        end

        amazon_s3 = Aws::S3::Resource.new(region: Rails.application.credentials.aws_s3_region, access_key_id: Rails.application.credentials.access_key_id, secret_access_key: Rails.application.credentials.secret_access_key)

        bucket = Rails.application.credentials.aws_bucket

        time = Time.now.strftime("%F %H:%M:%S").to_s.tr('-', '')

        file_name = "visibility_report_#{time.parameterize.underscore}"

        obj = amazon_s3.bucket(bucket).object("uploads/inward_visibility_reports/#{file_name}.csv")

        obj.put(body: file_csv, acl: 'public-read', content_disposition: 'attachment', content_type: 'text/csv')

        url = obj.public_url
        report = user.present? ? user.report_statuses.where(status: 'In Process', report_type: 'visiblity').last : nil
        if report.present?
          report.details = {}
          report.details['url'] = url
          report.details['completed_at_time'] = Time.now.in_time_zone('Mumbai').strftime("%d/%b/%Y - %I:%M %p")
          report.status = 'Completed'
          report.save
        end
        return url
      rescue
        report = user.present? ? user.report_statuses.where(status: 'In Process', report_type: 'visiblity').last : nil
        if report.present?
          report.details = {}
          report.details['failed_at_time'] = Time.now
          report.status = 'Failed'
          report.save
        end
      end
    end

    def self.export_outward_visibility_report(user = nil, duration=nil)

      begin
        distribution_centers_ids = user.distribution_centers.pluck(:id) if user.present?
        if duration.present?
          start_date = Date.new(Time.now.year,4,1).beginning_of_day
          end_date = (1.month.ago.end_of_month)
        else
          start_date = Date.today.beginning_of_month.beginning_of_day
          end_date = Date.today.end_of_day
        end
        inventory_closed_status = LookupValue.where(code: Rails.application.credentials.inventory_status_warehouse_closed_successfully).last
        if user.present?
          inventories = Inventory.includes(:inventory_grading_detail, :inventory_grading_details, :inventory_statuses, :inventory_documents, :gate_pass, :gate_pass_inventory, :vendor_return, :replacement, :insurance, :repair, :redeploy, :liquidation, :markdown, :e_waste, :pending_disposition, :vendor_returns, :replacements, :insurances, :repairs, :redeploys, :liquidations, :markdowns, :e_wastes, :pending_dispositions, distribution_center: [:city], warehouse_order_items: [warehouse_order: [:warehouse_order_documents]]).where(distribution_center_id: distribution_centers_ids, status_id: inventory_closed_status.try(:id), is_forward: false, updated_at: start_date..end_date, is_valid_inventory: true).order("(details ->> 'dispatch_date')::timestamptz ASC")
        else
          inventories = Inventory.includes(:inventory_grading_detail, :inventory_grading_details , :inventory_statuses, :inventory_documents, :gate_pass, :gate_pass_inventory, :vendor_return, :replacement, :insurance, :repair, :redeploy, :liquidation, :markdown, :e_waste, :pending_disposition, :vendor_returns, :replacements, :insurances, :repairs, :redeploys, :liquidations, :markdowns, :e_wastes, :pending_dispositions, distribution_center: [:city], warehouse_order_items: [warehouse_order: [:warehouse_order_documents]] ).where(status_id: inventory_closed_status.try(:id), is_forward: false, updated_at: start_date..end_date, is_valid_inventory: true).order("(details ->> 'dispatch_date')::timestamptz ASC")
        end

        file_types = LookupKey.where(code: "RETURN_REASON_FILE_TYPES").last
        invoice_file_type = file_types.lookup_values.where(original_code: "Customer Invoice").last
        order_file_types = LookupKey.where(code: "WAREHOUSE_ORDER_DOCUMENT_TYPES").last
        nrgp_file_type = order_file_types.lookup_values.where(original_code: "NRGP").last

        file_csv = CSV.generate do |csv|
          csv << ["Sr. No", "RPA Site Code", "Store Site Code", "Inward Scan ID", "Item Code", "Group Description", "Category Description", "Class Description", "Brand", "Brand Type", "Item description", "Serial Number", "GRN Date", "Resolution Date", "GRN Date DC", "Used Condition", "Inward Reason", "RPA Call log/Insurance claim/NER number", "Call log/insurance claim date", "Reason for liquidation", "Brand DT/CN/Claim number", "DT/CN/Claim Amount", "Functional condition", "Physical defect", "Accessories", "Packaging condition", "Inward Grade", "Regrade", "Lot Id", "Liquidation Lot name", "Liquidation/RTN Vendor code", "Vendor Name", "Dispatch Document number", "Dispatch date", "Liquidation grading user id"]

          inventories.each_with_index do |inventory, index|
            
            if inventory.serial_number.present?
              serial_number = inventory.serial_number.scan(/\D/).empty? ? "'" + inventory.serial_number :  inventory.serial_number
            else
              serial_number = ""
            end

            if inventory.sr_number.present?
              sr_number = inventory.sr_number.scan(/\D/).empty? ? "'" + inventory.sr_number :  inventory.sr_number
            else
              sr_number = ""
            end

            if ["Brand Approved DOA", "1) Brand Approved DOA"].include?(inventory.return_reason)
              remark = "Not eligible for testing / Not required"
              physical_remark = "NA"
            else
              remark = inventory.remarks
              physical_remark = inventory.physical_remark_old.present? ? inventory.physical_remark_old : inventory.physical_remark
            end

            if inventory.status_id == inventory_closed_status.id
              dispatch_date = inventory.inventory_statuses.last.created_at.to_date.strftime("%d/%b/%Y") rescue ""
              # dispatch_date = inventory.details['dispatch_date'].to_date.strftime("%d/%b/%Y") rescue ""
            else
              dispatch_date = ''
            end

            physical_condition = ""
            physical_condition_positions = ""
            physical_condition_hash = inventory.inventory_grading_detail.details["final_grading_result"]["Physical Condition"] rescue ""
            if physical_condition_hash.present?
              physical_condition_hash.each_with_index do |physical_condition_val, i|
                if physical_condition_val["test"].include? "Position"
                  unless physical_condition_val["value"].include?('NA')
                    physical_condition_positions += "/" unless physical_condition_positions.blank?
                    physical_condition_positions += physical_condition_val["value"]
                  end
                else
                  unless physical_condition_val["value"].include? "No" 
                    physical_condition += "/" unless physical_condition.blank?
                    physical_condition += physical_condition_val["value"]
                  end
                end
              end
              physical_condition = "No Physical Defect" if physical_condition.blank?
              physical_condition_positions = "NA" if physical_condition_positions.blank?
            elsif (inventory.inventory_grading_detail.details["final_grading_result"]["Physical"] rescue '').present?
              physical_condition_positions = "NA"
              physical_condition = inventory.physical_remark_old
            else
              physical_condition = "NA"
              physical_condition_positions = "NA"
            end


            if inventory.details["own_label"] == true
              brand_type = "OL"          
            else
              brand_type = "Non OL"
            end

            city = inventory.distribution_center.city.original_code rescue ""
            category_l1 = inventory.details["category_l1"] rescue ""
            category_l2 = inventory.details["category_l2"] rescue ""
            category_l3 = inventory.details["category_l3"] rescue ""

            used = inventory.details["processed_grading_result"]["Item Condition"] rescue ''
            value = used.try(:strip).try(:downcase)
            if used.present?
              if (value == "Un-used".downcase) || (value == "Unused".downcase)
                used = "NO"
              elsif (value == "Used".downcase) || (value == "Minor Used".downcase) || (value == "Major Used".downcase) || (value == "Complete damage".downcase)
                used = "YES"
              else
                used = used
              end
            else
              "NA"
            end
            
            accessories = inventory.details["processed_grading_result"]["Accessories"] rescue ''
            box_condition = (inventory.details["processed_grading_result"]["Packaging"].present? ? inventory.details["processed_grading_result"]["Packaging"] :  inventory.details["processed_grading_result"]["Packaging Condition"]) rescue ''

            pending_aging_from_grn = "#{(Date.today.to_date - inventory.details["grn_received_time"].to_date).to_i}" rescue "0"
            closure_aging_from_grn = "#{(dispatch_date.to_date - inventory.details["grn_received_time"].to_date).to_i}" rescue "0"

            warehouse_order = inventory.warehouse_order_items.where.not(warehouse_order_id: nil).last.warehouse_order rescue ""
            
            doc = inventory.inventory_documents.where(document_name_id: invoice_file_type.id).last rescue ""
            if doc.present?
              invoice_ref = doc.reference_number
            elsif inventory.details['invoice_number'].present?
              invoice_ref = inventory.details['invoice_number']
            elsif inventory.details["document_text"].present?
              invoice_ref = inventory.details["document_text"]
            else
              invoice_ref = ''
            end

            if inventory.details["own_label"] == true
              brand_type = "OL"
            else
              brand_type = "Non OL"
            end
            
            if warehouse_order.present?
              dispatch_complete_date = warehouse_order.details["dispatch_complete_date"].to_date.strftime("%d/%b/%Y") rescue ""

              outward_invoice_number = warehouse_order.outward_invoice_number.present? ? warehouse_order.outward_invoice_number : "N/A"
              doc = warehouse_order.warehouse_order_documents.where(document_name_id: nrgp_file_type.id).last rescue ""
              nrgp_ref = doc.present? ? doc.reference_number : ""
              document_type =  warehouse_order.delivery_reference_number.present? ? warehouse_order.delivery_reference_number : ""
            else
              dispatch_complete_date = ""
              outward_invoice_number = ""
              document_type = ""
            end

            bucket = inventory.get_current_bucket
            call_log = ''
            call_log_or_claim_date = ''
            resolution_date = ''
            visit_date = ''
            if bucket.present?
              status = inventory.get_closed_status(bucket)
              order_date = inventory.get_order_date(bucket)
              call_log = bucket.call_log_id rescue ''
            else
              status = inventory.status rescue ''
            end

            vr =  inventory.vendor_return
            vr = inventory.vendor_returns.where.not(call_log_id: nil).last if vr.blank?
            insurance = inventory.insurance
            insurance = inventory.insurances.where.not(call_log_id: nil).last if insurance.blank?
            rep = inventory.replacement
            rep = inventory.replacements.where.not(call_log_id: nil).last if rep.blank?

            if vr.present?
              call_log = vr.call_log_id if call_log.blank?
              call_log_or_claim_date = vr.call_log_or_claim_date if call_log_or_claim_date.blank?
              resolution_date = vr.resolution_date_time.present? ? vr.resolution_date_time : vr.updated_at.to_date.strftime("%d/%b/%Y")
              visit_date = vr.brand_inspection_date.to_date.strftime("%d/%b/%Y") rescue ''
            elsif insurance.present?
              call_log = insurance.call_log_id if call_log.blank?
              call_log_or_claim_date = insurance.call_log_or_claim_date if call_log_or_claim_date.blank?
              resolution_date = insurance.resolution_date_time.present? ? insurance.resolution_date_time : insurance.updated_at.to_date.strftime("%d/%b/%Y")
            elsif rep.present?
              call_log = rep.call_log_id if call_log.blank?
              call_log_or_claim_date = rep.call_log_or_claim_date if call_log_or_claim_date.blank?
              resolution_date = rep.resolution_date_time.present? ? rep.resolution_date_time : rep.updated_at.to_date.strftime("%d/%b/%Y")
            end

            if call_log.blank? && inventory.details['return_reason_document_type'] == 'ner_number'
              call_log = inventory.details['document_text']
            end

            inventory_grading_details = inventory.inventory_grading_details.where(is_active:true).first
            orientation_arr = []
            orientation_hash = {}
            orientation_hash = {}
            final_hash = {}
            str = ""
            final_grading_result = inventory_grading_details.details["final_grading_result"] rescue {}
            if final_grading_result.present?
              final_grading_result.each do |k,v|
                v.each do |v1|
                  next unless v1['annotations']
                  v1["annotations"].each do |v2|
                    if v2["orientation"] != "Pack" && v2["text"] != "NA"
                      orientation_arr << (v2["orientation"] + " " + v2["text"]) rescue nil
                    end
                  end
                end
              end
              orientation_arr.compact.each do |value|
                if value.present?
                  if orientation_hash[value].present?
                    orientation_hash[value] = orientation_hash[value] + 1
                  else
                    orientation_hash[value] = 1
                  end 
                end
                processed_grading_result = inventory.details["processed_grading_result"]
                orientation_hash.each do |key,value|
                  str = str + "#{key} (#{value})\n"
                end
                if orientation_hash.present?
                  final_hash["Physical"] = str
                else
                  final_hash["Physical"] = processed_grading_result["Physical"] rescue ""
                end
              end
            end
            grn_date_status = (inventory.details["grn_received_time"].to_date.strftime("%d/%b/%Y") rescue 'NA')
            liquidation = Liquidation.find_by(tag_number: inventory.tag_number)
            if liquidation.present?
              policy =  liquidation.details['policy_type']
              credit_note = liquidation.details['credit_note_amount']
            else
              credit_note = "NA"
              policy = "NA"
            end
            item_condition = (inventory.details["processed_grading_result"].present? ? inventory.details["processed_grading_result"].except('Reason','Functional','Packaging' ,'Accessories','Physical').merge(final_hash).collect {|k| "#{k[0]}: #{k[1]}\n"}.join("") : '')
            item_condition = item_condition.remove("Item Condition: ").split("\n")[1]
            inward_grade = LookupValue.find_by_id(inventory.inventory_grading_details.first.grade_id).original_code rescue "N/A"
            regrade = LookupValue.find_by_id(inventory.inventory_grading_details.where(is_active: true).last.grade_id).original_code rescue "N/A"
            csv << [(index + 1),inventory.details["destination_code"], inventory.details["source_code"], inventory.tag_number, inventory.sku_code, category_l1, category_l2, category_l3, inventory.details["brand"], brand_type, inventory.item_description, serial_number, grn_date_status ,resolution_date, "", used, inventory.return_reason, call_log, call_log_or_claim_date, policy, "", credit_note, (inventory.details["processed_grading_result"].present? ? inventory.details["processed_grading_result"].extract!('Functional').collect {|k| "#{k[0]}: #{k[1]}\n"}.join("") : ''), physical_condition, accessories, box_condition, inward_grade, regrade, (inventory.order_id), (inventory.order_name), (inventory.vendor_code), (inventory.vendor_name), outward_invoice_number, dispatch_complete_date, inventory_grading_details&.user_id ]

          end
        end

        amazon_s3 = Aws::S3::Resource.new(region: Rails.application.credentials.aws_s3_region, access_key_id: Rails.application.credentials.access_key_id, secret_access_key: Rails.application.credentials.secret_access_key)

        bucket = Rails.application.credentials.aws_bucket

        time = Time.now.strftime("%F %H:%M:%S").to_s.tr('-', '')

        file_name = "outward_visibility_report_#{time.parameterize.underscore}"

        obj = amazon_s3.bucket(bucket).object("uploads/outward_visibility_reports/#{file_name}.csv")

        obj.put(body: file_csv, acl: 'public-read', content_disposition: 'attachment', content_type: 'text/csv')

        url = obj.public_url

        report = user.present? ? user.report_statuses.where(status: 'In Process', report_type: 'outward').last : nil
        if report.present?
          report.details = {}
          report.details['url'] = url
          report.details['completed_at_time'] = Time.now
          report.status = 'Completed'
          report.save
        end

        return url
      rescue Exception => message
        report = user.present? ? user.report_statuses.where(status: 'In Process', report_type: 'outward').last : nil
        if report.present?
          report.details = {}
          report.details['url'] = url
          report.details['failed_at_time'] = Time.now
          report.status = 'Failed'
          report.save
        end
      end
  
    end
    def self.generate_and_send_yearly_report(report_type)
      url = export_outward_visibility_report(nil, 'yearly') if report_type == 'outward'
      url = timeline_report(nil, 'yearly') if report_type == 'inward'
      time = Time.now.in_time_zone('Mumbai').strftime("%F %I:%M:%S %p")
      # role = Role.find_by(code: 'central_admin')
      ReportMailer.visiblity_email(report_type, url, nil, email, time).deliver_now
      # role = Role.find_by(code: 'site_admin')
      # UserRole.where(role_id: role.id).each do |user_role|
      #   url = export_outward_visibility_report(user_role.user, 'yearly')
      #   ReportMailer.visiblity_email(report_type, url, user_role.user.id, user_role.user.email, time).deliver_now
      # end
    end

    def self.generate_and_send_monthly_report_daily(report_type)
      #To all admins
      url = export_outward_visibility_report if report_type == 'outward'
      url = timeline_report if report_type == 'inward'
      time = Time.now.in_time_zone('Mumbai').strftime("%F %I:%M:%S %p")
      ReportMailer.visiblity_email(report_type, url, nil, nil, time).deliver_now
      ReportStatus.where(report_for: 'central_admin', report_type: report_type).update_all(latest: false)
      rs = ReportStatus.new(report_for: 'central_admin', report_type: report_type, latest: true, status: 'Completed')
      rs.details = {}
      rs.details['completed_at_time'] = Time.now.in_time_zone('Mumbai')
      rs.details['url'] = url
      rs.save
      # TO all Site Admins
      # role = Role.find_by(code: 'site_admin')
      # UserRole.where(role_id: role.id).each do |user_role|
      #   url = export_outward_visibility_report(user_role.user) if report_type == 'outward'
      #   url = timeline_report(user_role.user, nil) if report_type == 'inward'
      #   ReportStatus.where(report_for: 'site_admin', report_type: report_type, user_id: user_role.user_id).update_all(latest: false)
      #   rs = ReportStatus.new(report_for: 'site_admin', report_type: report_type, latest: true, status: 'Completed', user_id: user_role.user_id, distribution_center_ids: user_role.user.distribution_centers.pluck(:id))
      #   rs.details = {}
      #   rs.details['completed_at_time'] = Time.now.in_time_zone('Mumbai')
      #   rs.details['url'] = url
      #   rs.save
      #   ReportMailer.visiblity_email(report_type, url, user_role.user.id, user_role.user.email, time).deliver_now
      # end
    end


    def self.generate_and_send_inward_visibility_report
      url = export_inward_visibility_report
      # role = Role.find_by(code: 'central_admin')
      time = Time.now.in_time_zone('Mumbai').strftime("%F %I:%M:%S %p")
      ReportMailer.visiblity_email('visiblity', url, nil, nil, time).deliver_now
      ReportStatus.where(report_for: 'central_admin', report_type: 'visiblity').update_all(latest: false)
      rs = ReportStatus.new(report_for: 'central_admin', report_type: 'visiblity', latest: true, status: 'Completed')
      rs.details = {}
      rs.details['completed_at_time'] = Time.now.in_time_zone('Mumbai')
      rs.details['url'] = url
      rs.save
      # TO all Site Admins
      # role = Role.find_by(code: 'site_admin')
      # UserRole.where(role_id: role.id).each do |user_role|
      #   url = export_outward_visibility_report(user_role.user)
      #   ReportStatus.where(report_for: 'site_admin', report_type: 'visiblity', user_id: user_role.user_id).update_all(latest: false)
      #   rs = ReportStatus.new(report_for: 'site_admin', report_type: 'visiblity', latest: true, status: 'Completed', user_id: user_role.user_id, distribution_center_ids: user_role.user.distribution_centers.pluck(:id))
      #   rs.details = {}
      #   rs.details['completed_at_time'] = Time.now.in_time_zone('Mumbai')
      #   rs.details['url'] = url
      #   rs.save
      #   ReportMailer.visiblity_email('visiblity', url, user_role.user.id, user_role.user.email, time).deliver_now
      # end
    end

    def self.timeline_report(user=nil, duration=nil)
      distribution_centers_ids = user.distribution_centers.pluck(:id) if user.present?
      if duration.present?
        start_date = Date.new(Time.now.year,4,1).beginning_of_day
        end_date = (1.month.ago.end_of_month)
      else
        start_date = Date.today.beginning_of_month.beginning_of_day
        end_date = Date.today.end_of_day
      end
      inventory_closed_status = LookupValue.where(code: Rails.application.credentials.inventory_status_warehouse_closed_successfully).last
      if user.present?
        inventories = Inventory.with_deleted.includes(:inventory_grading_detail, :inventory_grading_details, :inventory_statuses, :inventory_documents, :gate_pass, :gate_pass_inventory, :vendor_return, :replacement, :insurance, :repair, :redeploy, :liquidation, :markdown, :e_waste, :pending_disposition, :vendor_returns, :replacements, :insurances, :repairs, :redeploys, :liquidations, :markdowns, :e_wastes, :pending_dispositions, distribution_center: [:city], warehouse_order_items: [warehouse_order: [:warehouse_order_documents]]).where(distribution_center_id: distribution_centers_ids, is_forward: false, created_at: start_date..end_date).where("inventories.details ->> 'old_inventory_id' is null and (details ->> 'issue_type' != ? or details ->> 'issue_type' is null)", Rails.application.credentials.issue_type_in_transit).order("(details ->> 'dispatch_date')::timestamptz ASC")
      else
        inventories = Inventory.with_deleted.includes(:inventory_grading_detail, :inventory_grading_details, :inventory_statuses, :inventory_documents, :gate_pass, :gate_pass_inventory, :vendor_return, :replacement, :insurance, :repair, :redeploy, :liquidation, :markdown, :e_waste, :pending_disposition, :vendor_returns, :replacements, :insurances, :repairs, :redeploys, :liquidations, :markdowns, :e_wastes, :pending_dispositions, distribution_center: [:city], warehouse_order_items: [warehouse_order: [:warehouse_order_documents]]).where(is_forward: false, created_at: start_date..end_date).where("inventories.details ->> 'old_inventory_id' is null and (details ->> 'issue_type' != ? or details ->> 'issue_type' is null)", Rails.application.credentials.issue_type_in_transit).order("(details ->> 'dispatch_date')::timestamptz ASC")
      end
      file_types = LookupKey.where(code: "RETURN_REASON_FILE_TYPES").last
      invoice_file_type = file_types.lookup_values.where(original_code: "Customer Invoice").last
      order_file_types = LookupKey.where(code: "WAREHOUSE_ORDER_DOCUMENT_TYPES").last
      nrgp_file_type = order_file_types.lookup_values.where(original_code: "NRGP").last
      file_csv = CSV.generate do |csv|
        csv << ["Sl No", "RPA Site Code", "RPA Site Name", "Store Site Code", "Store Site Name", "Inward Scan ID", "Group Description", "Category Description", "Class Description", "Brand Type", "Item Code", "Item description", "Brand", "Serial Number", "Serial Number 2", "Qty", "MAP",
                "OBD Number", "OBD Date", "GRN Number", "GRN Date", "Used Condition",
                "Inward Reason", "Packaging condition", "Physical defect", "Physical defect position", "Accessories", "Invoice Number", "Grade", "Created At", "Deleted At", "Reason for Deletion"]

        inventories.each_with_index do |inventory, index|
          if inventory.serial_number.present?
            serial_number = inventory.serial_number.scan(/\D/).empty? ? "'" + inventory.serial_number :  inventory.serial_number
          else
            serial_number = "NA"
          end

          serial_number_2 = inventory.serial_number_2.present? ? inventory.serial_number_2 : "NA"

          if inventory.sr_number.present?
            sr_number = inventory.sr_number.scan(/\D/).empty? ? "'" + inventory.sr_number :  inventory.sr_number
          else
            sr_number = "NA"
          end

          if inventory.status_id == inventory_closed_status.id
            dispatch_date = inventory.inventory_statuses.last.created_at.to_date.strftime("%d/%b/%Y") rescue "NA"
            # dispatch_date = inventory.details['dispatch_date'].to_date.strftime("%d/%b/%Y") rescue ""
          else
            dispatch_date = 'NA'
          end

          if inventory.details["own_label"] == true
            brand_type = "OL"          
          else
            brand_type = "Non OL"
          end

          city = inventory.distribution_center.city.original_code rescue "NA"
          category_l1 = inventory.details["category_l1"] rescue "NA"
          category_l2 = inventory.details["category_l2"] rescue "NA"
          category_l3 = inventory.details["category_l3"] rescue "NA"

          used = inventory.details["processed_grading_result"]["Item Condition"] rescue ""
          if used.blank?
            used = "NA"
          end
          # used = used.present? ? (used.try(:strip).try(:downcase) == "Unused".downcase ? "NO" : "YES") : ''
          
          accessories = inventory.details["processed_grading_result"]["Accessories"] rescue 'NA'
          box_condition = (inventory.details["processed_grading_result"]["Packaging"].present? ? inventory.details["processed_grading_result"]["Packaging"] :  inventory.details["processed_grading_result"]["Packaging Condition"]) rescue ''
          if box_condition.blank?
            box_condition = "NA"
          end
         # pending_aging_from_grn = TimeDifference.between(inventory.details["grn_received_time"].to_date.strftime("%d/%b/%Y") , Time.now.to_s).in_days.ceil if inventory.details["grn_received_time"].present?
          # closure_aging_from_grn = TimeDifference.between(inventory.details["grn_received_time"].to_date.strftime("%d/%b/%Y") , dispatch_date).in_days.ceil if dispatch_date.present? && inventory.details["grn_received_time"].present?

          pending_aging_from_grn = "#{(Date.today.to_date - inventory.details["grn_received_time"].to_date).to_i}" rescue "0"
          closure_aging_from_grn = "#{(dispatch_date.to_date - inventory.details["grn_received_time"].to_date).to_i}" rescue "0"

          # warehouse_order = inventory.warehouse_order_items.last.warehouse_order rescue ""

          physical_condition = ""
          physical_condition_positions = ""
          physical_condition_hash = inventory.inventory_grading_details.first.details["final_grading_result"]["Physical Condition"] rescue ""
          if physical_condition_hash.present?
            physical_condition_hash.each_with_index do |physical_condition_val, i|
              if physical_condition_val["test"].include? "Position"
                unless physical_condition_val["value"].include?('NA')
                  physical_condition_positions += "/" unless physical_condition_positions.blank?
                  physical_condition_positions += physical_condition_val["value"]
                end
              else
                unless physical_condition_val["value"].include? "No" 
                  physical_condition += "/" unless physical_condition.blank?
                  physical_condition += physical_condition_val["value"]
                end
              end
            end
            physical_condition = "No Physical Defect" if physical_condition.blank?
            physical_condition_positions = "NA" if physical_condition_positions.blank?
          elsif (inventory.inventory_grading_details.first.details["final_grading_result"]["Physical"] rescue '').present?
            physical_condition_positions = "NA"
            physical_condition = inventory.physical_remark_old
          else
            physical_condition = "NA"
            physical_condition_positions = "NA"
          end
          
          doc = inventory.inventory_documents.where(document_name_id: invoice_file_type.id).last
          if inventory.details["return_reason_document_type"] == invoice_file_type.code
            text_invoice_number = inventory.details["document_text"].present? ? inventory.details["document_text"] : "NA"
          elsif doc.present?
            text_invoice_number = doc.reference_number
          elsif inventory.details['invoice_number'].present?
            text_invoice_number = inventory.details['invoice_number'] 
          else
            text_invoice_number = "NA"
          end

          if inventory.details["own_label"] == true
            brand_type = "OL"          
          else
            brand_type = "Non OL"
          end
          
          # if warehouse_order.present?
          #   outward_invoice_number = warehouse_order.outward_invoice_number.present? ? warehouse_order.outward_invoice_number : "NA"
          #   doc = warehouse_order.warehouse_order_documents.where(document_name_id: nrgp_file_type.id).last rescue ""
          #   nrgp_ref = doc.present? ? doc.reference_number : "NA"
          #   document_type =  warehouse_order.delivery_reference_number.present? ? warehouse_order.delivery_reference_number : "NA"
          # else
          #   document_type = "NA"
          #   outward_invoice_number = "NA"
          # end

          bucket = inventory.get_current_bucket
          call_log = ''
          call_log_or_claim_date = ''
          resolution_date = ''
          visit_date = ''
          if bucket.present?
            status = inventory.get_status(bucket)
            order_date = inventory.get_order_date(bucket)
            call_log = bucket.call_log_id rescue ''
          else
            status = inventory.status rescue ''
          end

          vr =  inventory.vendor_return
          vr = inventory.vendor_returns.where.not(call_log_id: nil).last if vr.blank?
          insurance = inventory.insurance
          insurance = inventory.insurances.where.not(call_log_id: nil).last if insurance.blank?

          if vr.present?
            call_log = vr.call_log_id if call_log.blank?
            call_log_or_claim_date = vr.call_log_or_claim_date if call_log_or_claim_date.blank?
            resolution_date = vr.resolution_date_time.present? ? vr.resolution_date_time : vr.updated_at.to_date.strftime("%d/%b/%Y")
            visit_date = vr.brand_inspection_date.to_date.strftime("%d/%b/%Y") rescue ''
          elsif insurance.present?
            call_log = insurance.call_log_id if call_log.blank?
            call_log_or_claim_date = insurance.call_log_or_claim_date if call_log_or_claim_date.blank?
            resolution_date = insurance.resolution_date_time.present? ? insurance.resolution_date_time : insurance.updated_at.to_date.strftime("%d/%b/%Y")
          end



          grading_detail = inventory.inventory_grading_details.first
          orientation_arr = []
          orientation_hash = {}
          orientation_hash = {}
          final_hash = {}
          str = ""
          final_grading_result = grading_detail.details["final_grading_result"] rescue {}
          if final_grading_result.present?
            final_grading_result.each do |k,v|
              v.each do |v1|
                next unless v1['annotations']
                v1["annotations"].each do |v2|
                  if v2["orientation"] != "Pack" && v2["text"] != "NA"
                    orientation_arr << (v2["orientation"] + " " + v2["text"]) rescue nil
                  end
                end
              end
            end
            orientation_arr.compact.each do |value|
              if value.present?
                if orientation_hash[value].present?
                  orientation_hash[value] = orientation_hash[value] + 1
                else
                  orientation_hash[value] = 1
                end 
              end
              processed_grading_result = grading_detail.details["processed_grading_result"]
              orientation_hash.each do |key,value|
                str = str + "#{key} (#{value})\n"
              end
              if orientation_hash.present?
                final_hash["Physical"] = str
              else
                final_hash["Physical"] = processed_grading_result["Physical"] rescue ""
              end
            end
          end

          grn_date_status = (inventory.status=='Pending GRN') ? 'Pending for GRN' : (inventory.details["grn_received_time"].to_date.strftime("%d/%b/%Y") rescue 'NA')
          
          rpa_site_name = inventory.try(:distribution_center).try(:name) rescue nil
          store_site_name = DistributionCenter.where(code: inventory.details["source_code"]).last.name rescue nil
          
          item_condition = (grading_detail.details["processed_grading_result"].present? ? grading_detail.details["processed_grading_result"].except('Reason','Functional','Packaging' ,'Accessories','Physical').merge(final_hash).collect {|k| "#{k[0]}: #{k[1]}\n"}.join("") : '') rescue ''
          item_condition = item_condition.remove("Item Condition: ").split("\n")[1]

          csv << [(index + 1),inventory.details["destination_code"], rpa_site_name, inventory.details["source_code"], store_site_name, inventory.tag_number, category_l1, category_l2, category_l3, brand_type, inventory.sku_code,
                  inventory.item_description, inventory.details["brand"], serial_number, serial_number_2, inventory.quantity, inventory.item_price,
                  inventory.gate_pass&.client_gatepass_number, (inventory.details["dispatch_date"].to_date.strftime("%d/%b/%Y") rescue 'NA'),
                  inventory.details["grn_number"].present? ? inventory.details["grn_number"] : "NA", grn_date_status, used,  inventory.return_reason.present? ? inventory.return_reason : "NA", box_condition, physical_condition, physical_condition_positions.present? ? physical_condition_positions : "NA" , accessories, text_invoice_number,
                  inventory.try(:grade), inventory.created_at.strftime("%d/%m/%Y"), (inventory.deleted_at.strftime("%d/%m/%Y") rescue nil), inventory.details['reason_for_deletion']] if inventory.gate_pass.present?

        end
      end

      amazon_s3 = Aws::S3::Resource.new(region: Rails.application.credentials.aws_s3_region, access_key_id: Rails.application.credentials.access_key_id, secret_access_key: Rails.application.credentials.secret_access_key)

      bucket = Rails.application.credentials.aws_bucket

      time = Time.now.strftime("%F %H:%M:%S").to_s.tr('-', '')

      file_name = "inward_report_#{time.parameterize.underscore}"

      obj = amazon_s3.bucket(bucket).object("uploads/timeline_reports/#{file_name}.csv")

      obj.put(body: file_csv, acl: 'public-read', content_disposition: 'attachment', content_type: 'text/csv')

      url = obj.public_url
      
      return url
  
    end

    def self.get_status_id_of_buckets
      pending_dispatch_status = LookupValue.where(code: Rails.application.credentials.vendor_return_status_pending_dispatch).last #700
      rtv_closed_status = LookupValue.where(code: Rails.application.credentials.vendor_return_status_rtv_closed).last #733
      pending_settlement_status = LookupValue.where(code: Rails.application.credentials.vendor_return_status_pending_settlement).last #701
      insurance_closed_status = LookupValue.where(code: Rails.application.credentials.insurance_status_insurance_closed).last #748
      pending_replacement_closed_status = LookupValue.where(code: Rails.application.credentials.replacement_status_pending_replacement_closed).last #788
      redeploy_dispatch_complete_status = LookupValue.where(code: Rails.application.credentials.redeploy_status_redeploy_dispatch_complete).last #808
      pending_transfer_out_dispatch_complete_status = LookupValue.where(code: "markdown_status_pending_transfer_out_dispatch_complete").last #803
      pending_disposition_closed_status = LookupValue.where(code: Rails.application.credentials.pending_disposition_status_pending_disposition_closed).last #882

      pending_e_waste_status = LookupValue.where(code: Rails.application.credentials.e_waste_status_pending_e_waste).first #820 # 2 Values are present in QA.

      pending_claim_status = LookupValue.where(code: Rails.application.credentials.vendor_return_status_pending_claim).last #731
      pending_call_log_status = LookupValue.where(code: Rails.application.credentials.vendor_return_status_pending_call_log).last #697
      pending_brand_inspection_status = LookupValue.where(code: Rails.application.credentials.vendor_return_status_pending_brand_inspection).last #732
      pending_brand_approval_status = LookupValue.where(code: Rails.application.credentials.vendor_return_status_pending_brand_approval).last #698
      pending_insurance_submission_status = LookupValue.where(code: Rails.application.credentials.insurance_status_pending_insurance_submission).last #743
      pending_insurance_call_log_status = LookupValue.where(code: Rails.application.credentials.insurance_status_pending_insurance_call_log).last #744
      pending_insurance_inspection_status = LookupValue.where(code: Rails.application.credentials.insurance_status_pending_insurance_inspection).last #745
      pending_insurance_approval_status = LookupValue.where(code: Rails.application.credentials.insurance_status_pending_insurance_approval).last #746
      pending_insurance_disposition_status = LookupValue.where(code: Rails.application.credentials.insurance_status_pending_insurance_disposition).last #747
      pending_repair_initiation_status = LookupValue.where(code: Rails.application.credentials.repair_status_pending_repair_initiation).last #760
      pending_repair_quotation_status = LookupValue.where(code: Rails.application.credentials.repair_status_pending_repair_quotation).last #761
      pending_repair_approval_status = LookupValue.where(code: Rails.application.credentials.repair_status_pending_repair_approval).last #762
      pending_repair_status = LookupValue.where(code: Rails.application.credentials.repair_status_pending_repair).last #705
      pending_repair_grade_status = LookupValue.where(code: Rails.application.credentials.repair_status_pending_repair_grade).last #763
      pending_repair_disposition_status = LookupValue.where(code: Rails.application.credentials.repair_status_pending_repair_disposition).last #764
      pending_replacement_call_log_status = LookupValue.where(code: Rails.application.credentials.replacement_status_pending_replacement_call_log).last #785

      pending_replacement_inspection_status = LookupValue.where(code: Rails.application.credentials.replacement_status_pending_replacement_inspection).last #786
      pending_replacement_resolution_status = LookupValue.where(code: Rails.application.credentials.replacement_status_pending_replacement_resolution).last #787
      pending_replacement_replaced_status = LookupValue.where(code: Rails.application.credentials.replacement_status_pending_replacement_replaced).last #789
      pending_replacement_disposition_status = LookupValue.where(code: Rails.application.credentials.replacement_status_pending_replacement_disposition).last #791
      pending_liquidation_status = LookupValue.where(code: "liquidation_status_pending_liquidation").last #777
      pending_liquidation_regrade_status = LookupValue.where(code: "liquidation_status_pending_liquidation_regrade").last #778
      pending_lot_creation_status = LookupValue.where(code: "liquidation_status_pending_lot_creation").last #871
      pending_lot_dispatch_status = LookupValue.where(code: "liquidation_status_pending_lot_dispatch").last #779
      pending_transfer_out_destination_status = LookupValue.where(code: "markdown_status_pending_transfer_out_destination").last #801
      markdown_dispatch_status = LookupValue.where(code: Rails.application.credentials.markdown_file_type_markdown_dispatch).last #805
      pending_disposition_status = LookupValue.where(code: Rails.application.credentials.pending_disposition_status_pending_disposition).last #881
      pending_redeploy_destination_status = LookupValue.where(code: Rails.application.credentials.redeploy_status_pending_redeploy_destination).last #806
      pending_redeploy_dispatch_status = LookupValue.where(code: Rails.application.credentials.redeploy_status_pending_redeploy_dispatch).last #807

      return {pending_dispatch_status: pending_dispatch_status.id, rtv_closed_status: rtv_closed_status.id, pending_settlement_status: pending_settlement_status.id, insurance_closed_status: insurance_closed_status.id, pending_replacement_closed_status: pending_replacement_closed_status.id,redeploy_dispatch_complete_status: redeploy_dispatch_complete_status.id, pending_transfer_out_dispatch_complete_status: pending_transfer_out_dispatch_complete_status.id, pending_disposition_closed_status: pending_disposition_closed_status.id, pending_e_waste_status: pending_e_waste_status.id, pending_claim_status: pending_claim_status.id, pending_call_log_status: pending_call_log_status.id, pending_brand_inspection_status: pending_brand_inspection_status.id, pending_brand_approval_status: pending_brand_approval_status.id, pending_insurance_submission_status: pending_insurance_submission_status.id, pending_insurance_call_log_status: pending_insurance_call_log_status.id, pending_insurance_inspection_status: pending_insurance_inspection_status.id, pending_insurance_approval_status: pending_insurance_approval_status.id, pending_insurance_disposition_status: pending_insurance_disposition_status.id, pending_repair_initiation_status: pending_repair_initiation_status.id, pending_repair_quotation_status: pending_repair_quotation_status.id, pending_repair_approval_status: pending_repair_approval_status.id, pending_repair_status: pending_repair_status.id, pending_repair_grade_status: pending_repair_grade_status.id, pending_repair_disposition_status: pending_repair_disposition_status.id, pending_replacement_call_log_status: pending_replacement_call_log_status.id, pending_replacement_inspection_status: pending_replacement_inspection_status.id, pending_replacement_resolution_status: pending_replacement_resolution_status.id, pending_replacement_replaced_status: pending_replacement_replaced_status.id, pending_replacement_disposition_status: pending_replacement_disposition_status.id, pending_liquidation_status: pending_liquidation_status.id, pending_liquidation_regrade_status: pending_liquidation_regrade_status.id, pending_lot_creation_status: pending_lot_creation_status.id, pending_lot_dispatch_status: pending_lot_dispatch_status.id, pending_transfer_out_destination_status: pending_transfer_out_destination_status.id, markdown_dispatch_status: markdown_dispatch_status.id, pending_disposition_status: pending_disposition_status.id, pending_redeploy_destination_status: pending_redeploy_destination_status.id, pending_redeploy_dispatch_status: pending_redeploy_dispatch_status.id}

    end

    def self.export_daily_report(daily_report_type)
      case daily_report_type

      when "RPA Report"
        url  = get_rpa_report
      when "Brand Manager"
        url = get_brand_manager_report
      when "Overall RPA Inv"
        url = get_overall_rpa_inv_report
      when "Brand More Than 90"
        url = get_brand_more_than_ninty_report
      when "OL More Than 90"
        url = get_ol_more_than_ninty_report
      when "Brand Wise RPA Inv"
        url = brand_wise_rpa_report
      when "In-Transit"
        url = get_in_transit_report
      when "RPA In and Out Tracker"
        url = rpa_in_out_tracker
      when "RPA Sitewise Transfer"
        url = rpa_sitewise_transfer
      else
        return ""
      end
    end


    def self.get_rpa_report
      bucket_info_data = []
      brand_call_log_data = []
      rtv_data = []
      insurance_data = []
      repair_data = []
      markdown_data = []
      replacement_data = []
      redeploy_data = []
      liquidation_data = []
      pending_transfer_out_data = []
      pending_disposition_data = []
      e_waste_data = []


      sql = ActiveRecord::Base.connection.execute("SELECT \'rtv\' as disposition, COUNT(CASE WHEN X.own_label = 'true' then (X.id) END) AS OL, COUNT(CASE WHEN X.own_label  = 'false' then (X.id) END) AS Brand FROM (SELECT DISTINCT vendor_returns.id ,client_sku_masters.own_label FROM public.vendor_returns LEFT JOIN public.client_sku_masters ON vendor_returns.sku_code= client_sku_masters.code WHERE vendor_returns.is_active ='true' AND (vendor_returns.status_id = 700 OR vendor_returns.status_id = 701) AND vendor_returns.deleted_at is null GROUP BY vendor_returns.id,client_sku_masters.own_label)  X UNION ALL SELECT 'brand call log' as disposition, COUNT(CASE WHEN X.own_label = 'true' then (X.id) END) AS OL, COUNT(CASE WHEN X.own_label  = 'false' then (X.id) END) AS Brand FROM (SELECT DISTINCT vendor_returns.id ,client_sku_masters.own_label FROM public.vendor_returns LEFT JOIN public.client_sku_masters ON vendor_returns.sku_code= client_sku_masters.code WHERE vendor_returns.is_active ='true' AND vendor_returns.status_id != 700 AND (vendor_returns.status_id != 733 OR vendor_returns.status_id != 701) AND vendor_returns.deleted_at is null GROUP BY vendor_returns.id,client_sku_masters.own_label)  X UNION ALL SELECT 'Insurance' as disposition, COUNT(CASE WHEN X.own_label = 'true' then (X.id) END) AS OL, COUNT(CASE WHEN X.own_label  = 'false' then (X.id) END) AS Brand FROM (SELECT DISTINCT insurances.id ,client_sku_masters.own_label FROM public.insurances LEFT JOIN public.client_sku_masters ON insurances.sku_code= client_sku_masters.code WHERE insurances.is_active ='true' AND insurances.status_id != 748 GROUP BY insurances.id,client_sku_masters.own_label)  X UNION ALL SELECT \'Repair\' as disposition, COUNT(CASE WHEN X.own_label = 'true' then (X.id) END) AS OL, COUNT(CASE WHEN X.own_label  = 'false' then (X.id) END) AS Brand FROM (SELECT DISTINCT repairs.id ,client_sku_masters.own_label FROM public.repairs LEFT JOIN public.client_sku_masters ON repairs.sku_code= client_sku_masters.code WHERE repairs.is_active ='true' AND repairs.deleted_at is null GROUP BY repairs.id,client_sku_masters.own_label)  X UNION ALL SELECT 'Replacements' as disposition, COUNT(CASE WHEN X.own_label = 'true' then (X.id) END) AS OL, COUNT(CASE WHEN X.own_label  = 'false' then (X.id) END) AS Brand FROM (SELECT DISTINCT replacements.id ,client_sku_masters.own_label FROM public.replacements LEFT JOIN public.client_sku_masters ON replacements.sku_code= client_sku_masters.code WHERE replacements.is_active ='true' AND replacements.deleted_at is null AND replacements.status_id !=788 GROUP BY replacements.id,client_sku_masters.own_label)  X UNION ALL SELECT 'Redeploys' as disposition, COUNT(CASE WHEN X.own_label = 'true' then (X.id) END) AS OL, COUNT(CASE WHEN X.own_label  = 'false' then (X.id) END) AS Brand FROM (SELECT DISTINCT redeploys.id ,client_sku_masters.own_label FROM public.redeploys LEFT JOIN public.client_sku_masters ON redeploys.sku_code= client_sku_masters.code WHERE redeploys.is_active ='true' AND redeploys.deleted_at is null AND redeploys.status_id !=808 GROUP BY redeploys.id,client_sku_masters.own_label)  X UNION ALL SELECT 'Liquidation' as disposition, COUNT(CASE WHEN X.own_label = 'true' then (X.id) END) AS OL, COUNT(CASE WHEN X.own_label  = 'false' then (X.id) END) AS Brand FROM (SELECT DISTINCT liquidations.id ,client_sku_masters.own_label FROM public.liquidations LEFT JOIN public.client_sku_masters ON liquidations.sku_code= client_sku_masters.code WHERE liquidations.is_active ='true' AND liquidations.deleted_at is null GROUP BY liquidations.id,client_sku_masters.own_label)  X UNION ALL SELECT 'Pending transfer out' as disposition, COUNT(CASE WHEN X.own_label = 'true' then (X.id) END) AS OL, COUNT(CASE WHEN X.own_label  = 'false' then (X.id) END) AS Brand FROM (SELECT DISTINCT markdowns.id ,client_sku_masters.own_label FROM public.markdowns LEFT JOIN public.client_sku_masters ON markdowns.sku_code= client_sku_masters.code WHERE markdowns.is_active ='true' AND markdowns.deleted_at is null GROUP BY markdowns.id,client_sku_masters.own_label)  X UNION ALL SELECT 'Pending disposition' as disposition, COUNT(CASE WHEN X.own_label = 'true' then (X.id) END) AS OL, COUNT(CASE WHEN X.own_label  = 'false' then (X.id) END) AS Brand FROM (SELECT DISTINCT pending_dispositions.id ,client_sku_masters.own_label FROM public.pending_dispositions LEFT JOIN public.client_sku_masters ON pending_dispositions.sku_code= client_sku_masters.code WHERE pending_dispositions.is_active ='true' AND pending_dispositions.deleted_at is null AND pending_dispositions.status_id !=882 GROUP BY pending_dispositions.id,client_sku_masters.own_label)  X UNION ALL SELECT 'e_wastes' as disposition, COUNT(CASE WHEN X.own_label = 'true' then (X.id) END) AS OL, COUNT(CASE WHEN X.own_label  = 'false' then (X.id) END) AS Brand FROM (SELECT DISTINCT e_wastes.id ,client_sku_masters.own_label FROM public.e_wastes LEFT JOIN public.client_sku_masters ON e_wastes.sku_code= client_sku_masters.code WHERE e_wastes.is_active ='true' AND e_wastes.deleted_at is null AND e_wastes.status_id =820 GROUP BY e_wastes.id,client_sku_masters.own_label)  X")

      sql.each do |value|
        bucket_info_data << value
      end

      sql = ActiveRecord::Base.connection.execute("SELECT X.RPA_Site as \"Brand_call_log\", COUNT(CASE WHEN Date_diff <= 30  THEN X.tag_number END) AS \"0-30\", COUNT(CASE WHEN Date_diff >= 31 AND Date_diff <=45 THEN X.tag_number END) AS \"31-45\", COUNT(CASE WHEN Date_diff >= 46 AND Date_diff <=60 THEN X.tag_number END) AS \"46-60\", COUNT(CASE WHEN Date_diff >= 61 AND Date_diff <=90 THEN X.tag_number END) AS \"61-90\", COUNT(CASE WHEN Date_diff >= 90 THEN X.tag_number END) AS \"90+\"FROM (SELECT tag_number,details->'destination_code' AS RPA_Site, DATE_PART('day',(now()- created_at)) AS Date_diff FROM public.vendor_returns WHERE is_active='true' and status_id !=700 AND (status_id !=733 or status_id !=701)AND deleted_at is null ) X GROUP BY X.RPA_Site")
      sql.each do |value|
        brand_call_log_data << value
      end

      sql = ActiveRecord::Base.connection.execute("SELECT X.RPA_Site as rtv, COUNT(CASE WHEN Date_diff <= 30  THEN X.tag_number END) AS \"0-30\", COUNT(CASE WHEN Date_diff >= 31 AND Date_diff <=45 THEN X.tag_number END) AS \"31-45\", COUNT(CASE WHEN Date_diff >= 46 AND Date_diff <=60 THEN X.tag_number END) AS \"46-60\", COUNT(CASE WHEN Date_diff >= 61 AND Date_diff <=90 THEN X.tag_number END) AS \"61-90\", COUNT(CASE WHEN Date_diff >= 90 THEN X.tag_number END) AS \"90+\"FROM (SELECT tag_number,details->'destination_code' AS RPA_Site, DATE_PART('day',(now()- created_at)) AS Date_diff FROM public.vendor_returns where is_active='true' AND (status_id =700 or status_id =701) AND deleted_at is null ) X GROUP BY X.RPA_Site")
      sql.each do |value|
        rtv_data << value
      end

      sql = ActiveRecord::Base.connection.execute("SELECT X.RPA_Site as Insurances, COUNT(CASE WHEN Date_diff <= 30  THEN X.tag_number END) AS \"0-30\", COUNT(CASE WHEN Date_diff >= 31 AND Date_diff <=45 THEN X.tag_number END) AS \"31-45\", COUNT(CASE WHEN Date_diff >= 46 AND Date_diff <=60 THEN X.tag_number END) AS \"46-60\", COUNT(CASE WHEN Date_diff >= 61 AND Date_diff <=90 THEN X.tag_number END) AS \"61-90\", COUNT(CASE WHEN Date_diff >= 90 THEN X.tag_number END) AS \"90+\"FROM (SELECT tag_number,details->'destination_code' AS RPA_Site, DATE_PART('day',(now()- created_at)) AS Date_diff FROM public.insurances WHERE status_id !=748 AND is_active = 'true' AND deleted_at is null) X GROUP BY X.RPA_Site")
      sql.each do |value|
        insurance_data << value
      end

      sql = ActiveRecord::Base.connection.execute("SELECT X.RPA_Site as Repair, COUNT(CASE WHEN Date_diff <= 30  THEN X.tag_number END) AS \"0-30\", COUNT(CASE WHEN Date_diff >= 31 AND Date_diff <=45 THEN X.tag_number END) AS \"31-45\", COUNT(CASE WHEN Date_diff >= 46 AND Date_diff <=60 THEN X.tag_number END) AS \"46-60\", COUNT(CASE WHEN Date_diff >= 61 AND Date_diff <=90 THEN X.tag_number END) AS \"61-90\", COUNT(CASE WHEN Date_diff >= 90 THEN X.tag_number END) AS \"90+\"FROM (SELECT location AS RPA_Site,tag_number, DATE_PART('day',(now()-created_at)) AS Date_diff FROM public.repairs WHERE is_active ='true' AND deleted_at is null) X GROUP BY X.RPA_Site")
      sql.each do |value|
        repair_data << value
      end

      sql = ActiveRecord::Base.connection.execute("SELECT X.RPA_Site as replacement, COUNT(CASE WHEN Date_diff <= 30  THEN X.tag_number END) AS \"0-30\", COUNT(CASE WHEN Date_diff >= 31 AND Date_diff <=45 THEN X.tag_number END) AS \"31-45\", COUNT(CASE WHEN Date_diff >= 46 AND Date_diff <=60 THEN X.tag_number END) AS \"46-60\", COUNT(CASE WHEN Date_diff >= 61 AND Date_diff <=90 THEN X.tag_number END) AS \"61-90\", COUNT(CASE WHEN Date_diff >= 90 THEN X.tag_number END) AS \"90+\"FROM (SELECT tag_number,details->'destination_code' AS RPA_Site, DATE_PART('day',(now()- created_at)) AS Date_diff FROM public.replacements WHERE is_active='true' AND status_id !=788) X GROUP BY X.RPA_Site")
      sql.each do |value|
        replacement_data << value
      end

      sql = ActiveRecord::Base.connection.execute("SELECT X.RPA_Site as redeploys, COUNT(CASE WHEN Date_diff <= 30  THEN X.tag_number END) AS \"0-30\", COUNT(CASE WHEN Date_diff >= 31 AND Date_diff <=45 THEN X.tag_number END) AS \"31-45\", COUNT(CASE WHEN Date_diff >= 46 AND Date_diff <=60 THEN X.tag_number END) AS \"46-60\", COUNT(CASE WHEN Date_diff >= 61 AND Date_diff <=90 THEN X.tag_number END) AS \"61-90\", COUNT(CASE WHEN Date_diff >= 90 THEN X.tag_number END) AS \"90+\"FROM (SELECT tag_number,details->'destination_code' AS RPA_Site, DATE_PART('day',(now()- created_at)) AS Date_diff FROM public.redeploys WHERE is_active='true' AND status_id !=808  AND deleted_at is null) X GROUP BY X.RPA_Site")
      sql.each do |value|
        redeploy_data << value
      end

      sql = ActiveRecord::Base.connection.execute("SELECT X.RPA_Site as liquidation, COUNT(CASE WHEN Date_diff <= 30  THEN X.tag_number END) AS \"0-30\", COUNT(CASE WHEN Date_diff >= 31 AND Date_diff <=45 THEN X.tag_number END) AS \"31-45\", COUNT(CASE WHEN Date_diff >= 46 AND Date_diff <=60 THEN X.tag_number END) AS \"46-60\", COUNT(CASE WHEN Date_diff >= 61 AND Date_diff <=90 THEN X.tag_number END) AS \"61-90\", COUNT(CASE WHEN Date_diff >= 90 THEN X.tag_number END) AS \"90+\"FROM (SELECT tag_number,details->'destination_code' AS RPA_Site, DATE_PART('day',(now()- created_at)) AS Date_diff FROM public.liquidations WHERE is_active='true' AND deleted_at is null AND deleted_at is null) X GROUP BY X.RPA_Site")
      sql.each do |value|
        liquidation_data << value
      end

      sql = ActiveRecord::Base.connection.execute("SELECT X.RPA_Site as \"pending_transfer_out\", COUNT(CASE WHEN Date_diff <= 30  THEN X.tag_number END) AS \"0-30\", COUNT(CASE WHEN Date_diff >= 31 AND Date_diff <=45 THEN X.tag_number END) AS \"31-45\", COUNT(CASE WHEN Date_diff >= 46 AND Date_diff <=60 THEN X.tag_number END) AS \"46-60\", COUNT(CASE WHEN Date_diff >= 61 AND Date_diff <=90 THEN X.tag_number END) AS \"61-90\", COUNT(CASE WHEN Date_diff >= 90 THEN X.tag_number END) AS \"90+\"FROM (SELECT tag_number,details->'destination_code' AS RPA_Site, DATE_PART('day',(now()- created_at)) AS Date_diff FROM public.markdowns WHERE is_active='true' AND status_id !=803 AND deleted_at is null) X GROUP BY X.RPA_Site")
      sql.each do |value|
        markdown_data << value
      end

      sql = ActiveRecord::Base.connection.execute("SELECT X.RPA_Site as \"pending_disposition\", COUNT(CASE WHEN Date_diff <= 30  THEN X.tag_number END) AS \"0-30\", COUNT(CASE WHEN Date_diff >= 31 AND Date_diff <=45 THEN X.tag_number END) AS \"31-45\", COUNT(CASE WHEN Date_diff >= 46 AND Date_diff <=60 THEN X.tag_number END) AS \"46-60\", COUNT(CASE WHEN Date_diff >= 61 AND Date_diff <=90 THEN X.tag_number END) AS \"61-90\", COUNT(CASE WHEN Date_diff >= 90 THEN X.tag_number END) AS \"90+\"FROM (SELECT tag_number,details->'destination_code' AS RPA_Site, DATE_PART('day',(now()- created_at)) AS Date_diff FROM public.pending_dispositions WHERE is_active='true' AND status_id !=882 AND deleted_at is null) X GROUP BY X.RPA_Site")
      sql.each do |value|
        pending_disposition_data << value
      end

      sql = ActiveRecord::Base.connection.execute("SELECT X.RPA_Site as \"e_waste\", COUNT(CASE WHEN Date_diff <= 30  THEN X.tag_number END) AS \"0-30\", COUNT(CASE WHEN Date_diff >= 31 AND Date_diff <=45 THEN X.tag_number END) AS \"31-45\", COUNT(CASE WHEN Date_diff >= 46 AND Date_diff <=60 THEN X.tag_number END) AS \"46-60\", COUNT(CASE WHEN Date_diff >= 61 AND Date_diff <=90 THEN X.tag_number END) AS \"61-90\", COUNT(CASE WHEN Date_diff >= 90 THEN X.tag_number END) AS \"90+\"FROM (SELECT location AS RPA_Site,tag_number, DATE_PART('day',(now()-created_at)) AS Date_diff FROM public.e_wastes WHERE is_active='true' and  status_id=820 AND deleted_at is null) X GROUP BY X.RPA_Site")
      sql.each do |value|
        e_waste_data << value
      end

      file_csv = CSV.generate do |csv|
        
        csv << ["Disposition", "Brand", "OL", "Overall RPA"]
        bucket_info_data.each do |bucket_info|
          if bucket_info["disposition"].present?
            csv << [bucket_info["disposition"], bucket_info["brand"], bucket_info["ol"], (bucket_info["ol"].to_i + bucket_info["brand"].to_i) ]
          end
        end

        csv << []

        csv << ["Brand Call Log", "0 - 30", "31 - 45", "46 - 60", "61 - 90", "90+", "Total"]
        column_count = 0
        brand_call_log_data.each do |brand_call_log|
          total = brand_call_log["0-30"].to_i + brand_call_log["31-45"].to_i + brand_call_log["46-60"].to_i + brand_call_log["61-90"].to_i + brand_call_log["90+"].to_i
          column_count += total
          csv << [brand_call_log["Brand_call_log"], brand_call_log["0-30"], brand_call_log["31-45"], brand_call_log["46-60"], brand_call_log["61-90"], brand_call_log["90+"], total]
        end
        zero_to_thirty_count = brand_call_log_data.select{|i| i['0-30'].present?}.inject(0) {|sum, hash| sum + hash["0-30"]}
        fourty_five_count = brand_call_log_data.select{|i| i['31-45'].present?}.inject(0) {|sum, hash| sum + hash["31-45"]}
        sixty_count = brand_call_log_data.select{|i| i['46-60'].present?}.inject(0) {|sum, hash| sum + hash["46-60"]}
        ninty_count = brand_call_log_data.select{|i| i['61-90'].present?}.inject(0) {|sum, hash| sum + hash["61-90"]}
        ninty_plus_count = brand_call_log_data.select{|i| i['90+'].present?}.inject(0) {|sum, hash| sum + hash['90+']}
        csv << ['Total', zero_to_thirty_count, fourty_five_count, sixty_count, ninty_count, ninty_plus_count, column_count]

        csv << []

        csv << ["RTV", "0 - 30", "31 - 45", "46 - 60", "61 - 90", "90+", "Total"]
        column_count = 0
        rtv_data.each do |rtv|
          total = rtv["0-30"].to_i + rtv["31-45"].to_i + rtv["46-60"].to_i + rtv["61-90"].to_i + rtv["90+"].to_i
          column_count += total
          csv << [rtv["rtv"], rtv["0-30"], rtv["31-45"], rtv["46-60"], rtv["61-90"], rtv["90+"], total]
        end
        zero_to_thirty_count = rtv_data.select{|i| i['0-30'].present?}.inject(0) {|sum, hash| sum + hash["0-30"]}
        fourty_five_count = rtv_data.select{|i| i['31-45'].present?}.inject(0) {|sum, hash| sum + hash["31-45"]}
        sixty_count = rtv_data.select{|i| i['46-60'].present?}.inject(0) {|sum, hash| sum + hash["46-60"]}
        ninty_count = rtv_data.select{|i| i['61-90'].present?}.inject(0) {|sum, hash| sum + hash["61-90"]}
        ninty_plus_count = rtv_data.select{|i| i['90+'].present?}.inject(0) {|sum, hash| sum + hash['90+']}
        csv << ['Total', zero_to_thirty_count, fourty_five_count, sixty_count, ninty_count, ninty_plus_count, column_count]

        csv << []
        csv << ["Insurance", "0 - 30", "31 - 45", "46 - 60", "61 - 90", "90+", "Total"]
        column_count = 0
        insurance_data.each do |insurance|
          total = insurance["0-30"].to_i + insurance["31-45"].to_i + insurance["46-60"].to_i + insurance["61-90"].to_i + insurance["90+"].to_i
          column_count += total
          csv << [insurance["insurances"], insurance["0-30"], insurance["31-45"], insurance["46-60"], insurance["61-90"], insurance["90+"], total]
        end

        zero_to_thirty_count = insurance_data.select{|i| i['0-30'].present?}.inject(0) {|sum, hash| sum + hash["0-30"]}
        fourty_five_count = insurance_data.select{|i| i['31-45'].present?}.inject(0) {|sum, hash| sum + hash["31-45"]}
        sixty_count = insurance_data.select{|i| i['46-60'].present?}.inject(0) {|sum, hash| sum + hash["46-60"]}
        ninty_count = insurance_data.select{|i| i['61-90'].present?}.inject(0) {|sum, hash| sum + hash["61-90"]}
        ninty_plus_count = insurance_data.select{|i| i['90+'].present?}.inject(0) {|sum, hash| sum + hash['90+']}
        csv << ['Total', zero_to_thirty_count, fourty_five_count, sixty_count, ninty_count, ninty_plus_count, column_count]

        csv << []
        csv << ["Repair", "0 - 30", "31 - 45", "46 - 60", "61 - 90", "90+", "Total"]
        column_count = 0
        repair_data.each do |repair|
          total = repair["0-30"].to_i + repair["31-45"].to_i + repair["46-60"].to_i + repair["61-90"].to_i + repair["90+"].to_i
          column_count += total
          csv << [repair["repair"], repair["0-30"], repair["31-45"], repair["46-60"], repair["61-90"], repair["90+"], total]
        end

        zero_to_thirty_count = repair_data.select{|i| i['0-30'].present?}.inject(0) {|sum, hash| sum + hash["0-30"]}
        fourty_five_count = repair_data.select{|i| i['31-45'].present?}.inject(0) {|sum, hash| sum + hash["31-45"]}
        sixty_count = repair_data.select{|i| i['46-60'].present?}.inject(0) {|sum, hash| sum + hash["46-60"]}
        ninty_count = repair_data.select{|i| i['61-90'].present?}.inject(0) {|sum, hash| sum + hash["61-90"]}
        ninty_plus_count = repair_data.select{|i| i['90+'].present?}.inject(0) {|sum, hash| sum + hash['90+']}
        csv << ['Total', zero_to_thirty_count, fourty_five_count, sixty_count, ninty_count, ninty_plus_count, column_count]

        csv << []
        csv << ["Replacement", "0 - 30", "31 - 45", "46 - 60", "61 - 90", "90+", "Total"]
        column_count = 0
        replacement_data.each do |replacement|
          total = replacement["0-30"].to_i + replacement["31-45"].to_i + replacement["46-60"].to_i + replacement["61-90"].to_i + replacement["90+"].to_i
          column_count += total
          csv << [replacement["replacement"], replacement["0-30"], replacement["31-45"], replacement["46-60"], replacement["61-90"], replacement["90+"], total]
        end

        zero_to_thirty_count = replacement_data.select{|i| i['0-30'].present?}.inject(0) {|sum, hash| sum + hash["0-30"]}
        fourty_five_count = replacement_data.select{|i| i['31-45'].present?}.inject(0) {|sum, hash| sum + hash["31-45"]}
        sixty_count = replacement_data.select{|i| i['46-60'].present?}.inject(0) {|sum, hash| sum + hash["46-60"]}
        ninty_count = replacement_data.select{|i| i['61-90'].present?}.inject(0) {|sum, hash| sum + hash["61-90"]}
        ninty_plus_count = replacement_data.select{|i| i['90+'].present?}.inject(0) {|sum, hash| sum + hash['90+']}
        csv << ['Total', zero_to_thirty_count, fourty_five_count, sixty_count, ninty_count, ninty_plus_count, column_count]

        csv << []
        csv << ["Redeploy", "0 - 30", "31 - 45", "46 - 60", "61 - 90", "90+", "Total"]
        column_count = 0
        redeploy_data.each do |redeploy|
          total = redeploy["0-30"].to_i + redeploy["31-45"].to_i + redeploy["46-60"].to_i + redeploy["61-90"].to_i + redeploy["90+"].to_i
          column_count += total
          csv << [redeploy["redeploys"], redeploy["0-30"], redeploy["31-45"], redeploy["46-60"], redeploy["61-90"], redeploy["90+"], total]
        end
        zero_to_thirty_count = redeploy_data.select{|i| i['0-30'].present?}.inject(0) {|sum, hash| sum + hash["0-30"]}
        fourty_five_count = redeploy_data.select{|i| i['31-45'].present?}.inject(0) {|sum, hash| sum + hash["31-45"]}
        sixty_count = redeploy_data.select{|i| i['46-60'].present?}.inject(0) {|sum, hash| sum + hash["46-60"]}
        ninty_count = redeploy_data.select{|i| i['61-90'].present?}.inject(0) {|sum, hash| sum + hash["61-90"]}
        ninty_plus_count = redeploy_data.select{|i| i['90+'].present?}.inject(0) {|sum, hash| sum + hash['90+']}
        csv << ['Total', zero_to_thirty_count, fourty_five_count, sixty_count, ninty_count, ninty_plus_count, column_count]

        csv << []
        csv << ["Liquidation", "0 - 30", "31 - 45", "46 - 60", "61 - 90", "90+", "Total"]
        column_count = 0
        liquidation_data.each do |liquidation|
          total = liquidation["0-30"].to_i + liquidation["31-45"].to_i + liquidation["46-60"].to_i + liquidation["61-90"].to_i + liquidation["90+"].to_i
          column_count += total
          csv << [liquidation["liquidation"], liquidation["0-30"], liquidation["31-45"], liquidation["46-60"], liquidation["61-90"], liquidation["90+"], total]
        end

        zero_to_thirty_count = liquidation_data.select{|i| i['0-30'].present?}.inject(0) {|sum, hash| sum + hash["0-30"]}
        fourty_five_count = liquidation_data.select{|i| i['31-45'].present?}.inject(0) {|sum, hash| sum + hash["31-45"]}
        sixty_count = liquidation_data.select{|i| i['46-60'].present?}.inject(0) {|sum, hash| sum + hash["46-60"]}
        ninty_count = liquidation_data.select{|i| i['61-90'].present?}.inject(0) {|sum, hash| sum + hash["61-90"]}
        ninty_plus_count = liquidation_data.select{|i| i['90+'].present?}.inject(0) {|sum, hash| sum + hash['90+']}
        csv << ['Total', zero_to_thirty_count, fourty_five_count, sixty_count, ninty_count, ninty_plus_count, column_count]

        csv << []
        csv << ["Pending Transfer Out", "0 - 30", "31 - 45", "46 - 60", "61 - 90", "90+", "Total"]
        column_count = 0
        markdown_data.each do |markdown|
          total = markdown["0-30"].to_i + markdown["31-45"].to_i + markdown["46-60"].to_i + markdown["61-90"].to_i + markdown["90+"].to_i
          column_count += total
          csv << [markdown["pending_transfer_out"], markdown["0-30"], markdown["31-45"], markdown["46-60"], markdown["61-90"], markdown["90+"], total]
        end

        zero_to_thirty_count = markdown_data.select{|i| i['0-30'].present?}.inject(0) {|sum, hash| sum + hash["0-30"]}
        fourty_five_count = markdown_data.select{|i| i['31-45'].present?}.inject(0) {|sum, hash| sum + hash["31-45"]}
        sixty_count = markdown_data.select{|i| i['46-60'].present?}.inject(0) {|sum, hash| sum + hash["46-60"]}
        ninty_count = markdown_data.select{|i| i['61-90'].present?}.inject(0) {|sum, hash| sum + hash["61-90"]}
        ninty_plus_count = markdown_data.select{|i| i['90+'].present?}.inject(0) {|sum, hash| sum + hash['90+']}
        csv << ['Total', zero_to_thirty_count, fourty_five_count, sixty_count, ninty_count, ninty_plus_count, column_count]

        csv << []
        csv << ["Pending Disposition", "0 - 30", "31 - 45", "46 - 60", "61 - 90", "90+", "Total"]
        column_count = 0
        pending_disposition_data.each do |pending_disposition|
          total = pending_disposition["0-30"].to_i + pending_disposition["31-45"].to_i + pending_disposition["46-60"].to_i + pending_disposition["61-90"].to_i + pending_disposition["90+"].to_i
          column_count += total
          csv << [pending_disposition["pending_disposition"], pending_disposition["0-30"], pending_disposition["31-45"], pending_disposition["46-60"], pending_disposition["61-90"], pending_disposition["90+"], total]
        end

        zero_to_thirty_count = pending_disposition_data.select{|i| i['0-30'].present?}.inject(0) {|sum, hash| sum + hash["0-30"]}
        fourty_five_count = pending_disposition_data.select{|i| i['31-45'].present?}.inject(0) {|sum, hash| sum + hash["31-45"]}
        sixty_count = pending_disposition_data.select{|i| i['46-60'].present?}.inject(0) {|sum, hash| sum + hash["46-60"]}
        ninty_count = pending_disposition_data.select{|i| i['61-90'].present?}.inject(0) {|sum, hash| sum + hash["61-90"]}
        ninty_plus_count = pending_disposition_data.select{|i| i['90+'].present?}.inject(0) {|sum, hash| sum + hash['90+']}
        csv << ['Total', zero_to_thirty_count, fourty_five_count, sixty_count, ninty_count, ninty_plus_count, column_count]

        csv << []
        csv << ["E-Waste", "0 - 30", "31 - 45", "46 - 60", "61 - 90", "90+", "Total"]
        column_count = 0
        e_waste_data.each do |e_waste|
          total = e_waste["0-30"].to_i + e_waste["31-45"].to_i + e_waste["46-60"].to_i + e_waste["61-90"].to_i + e_waste["90+"].to_i
          column_count += 0
          csv << [e_waste["e_waste"], e_waste["0-30"], e_waste["31-45"], e_waste["46-60"], e_waste["61-90"], e_waste["90+"], total]
        end

        zero_to_thirty_count = e_waste_data.select{|i| i['0-30'].present?}.inject(0) {|sum, hash| sum + hash["0-30"]}
        fourty_five_count = e_waste_data.select{|i| i['31-45'].present?}.inject(0) {|sum, hash| sum + hash["31-45"]}
        sixty_count = e_waste_data.select{|i| i['46-60'].present?}.inject(0) {|sum, hash| sum + hash["46-60"]}
        ninty_count = e_waste_data.select{|i| i['61-90'].present?}.inject(0) {|sum, hash| sum + hash["61-90"]}
        ninty_plus_count = e_waste_data.select{|i| i['90+'].present?}.inject(0) {|sum, hash| sum + hash['90+']}
        csv << ['Total', zero_to_thirty_count, fourty_five_count, sixty_count, ninty_count, ninty_plus_count, column_count]

      end

      amazon_s3 = Aws::S3::Resource.new(region: Rails.application.credentials.aws_s3_region, access_key_id: Rails.application.credentials.access_key_id, secret_access_key: Rails.application.credentials.secret_access_key)

      bucket = Rails.application.credentials.aws_bucket

      time = Time.now.strftime("%F %H:%M:%S").to_s.tr('-', '')

      file_name = "daily_report_#{time.parameterize.underscore}"

      obj = amazon_s3.bucket(bucket).object("uploads/daily_reports/#{file_name}.csv")

      obj.put(body: file_csv, acl: 'public-read', content_disposition: 'attachment', content_type: 'text/csv')

      url = obj.public_url
      
      return url
    
    end


    def order_id
      bucket = self.get_current_bucket
      if bucket.class.name == 'Liquidation'
        return "L-#{bucket.liquidation_order.id}" rescue "NA"
      elsif bucket.class.name == 'Redeploy'
        return "R-#{bucket.redeploy_order.id}" rescue "NA"
      elsif bucket.class.name == 'VendorReturn'
        return "RTV-#{bucket.vendor_return_order.id}" rescue "NA"
      else
        return "NA"
      end
    end

    def order_name
      bucket = self.get_current_bucket
      if bucket.class.name == 'Liquidation'
        return bucket.liquidation_order.lot_name rescue "NA"
      elsif bucket.class.name == 'Redeploy'
        return bucket.redeploy_order.lot_name rescue "NA" 
      elsif bucket.class.name == 'VendorReturn'
        return bucket.vendor_return_order.lot_name rescue "NA"
      end
    end

    def vendor_code
      bucket = self.get_current_bucket
      if bucket.class.name == 'Liquidation'
        lo = bucket.liquidation_order
        return lo&.winner_code || "NA" rescue "NA"
      elsif bucket.class.name == 'Redeploy'
        return bucket.redeploy_order.vendor_code rescue "NA"
      elsif bucket.class.name == 'VendorReturn'
        return bucket.vendor_return_order.vendor_code rescue "NA"
      else
        return self.details['vendor_code'] rescue 'NA'
      end
    end

    def vendor_name
      bucket = self.get_current_bucket
      if bucket.class.name == 'Liquidation'
        lo = bucket.liquidation_order
        if lo&.lot_type == 'Beam Lot'
          return lo.winner_code || "NA" rescue "NA"
        elsif lo&.lot_type == 'Email Lot' || lo&.lot_type == 'Contract Lot'
          return VendorMaster.find_by_vendor_code(lo.winner_code).vendor_name rescue 'N/A'
        else
          return "NA"
        end
      elsif bucket.class.name == 'Redeploy'
        return VendorMaster.find_by_vendor_code(bucket.redeploy_order.vendor_code).vendor_name rescue 'N/A'
      elsif bucket.class.name == 'VendorReturn'
        return VendorMaster.find_by_vendor_code(bucket.vendor_return_order.vendor_code).vendor_name rescue 'N/A'
      else
        return self.details['supplier'] rescue 'NA'
      end
    end

    def self.get_brand_manager_report
      brand_manager_data = []
      brand_manager_ol_data = []

      sql = ActiveRecord::Base.connection.execute("SELECT  X.RPA_Site_Code, COUNT(CASE WHEN X.V_active='true' AND X.V_id!=700 AND X.V_id != 733 AND X.V_id !=701 AND X.V_delete is null THEN X.ID END) AS \"Brand_call_log\", COUNT(CASE WHEN X.V_id = '700' OR X.V_id = '701' AND X.V_active='true' AND X.V_delete is null THEN X.ID END) as rtv, COUNT(CASE WHEN X.I_id != 748 AND X.I_active='true' AND X.I_delete is null THEN X.ID END) AS Insurance, COUNT(CASE WHEN X.R_active='true' AND X.R_delete is null THEN X.ID END ) AS Repair, COUNT(CASE WHEN X.RP_id != 788 AND X.RP_active='true' AND X.RP_delete is null THEN X.ID END) AS Replacement, COUNT(CASE WHEN X.L_active='true' AND X.L_delete is null THEN X.ID END ) AS Liquidation, COUNT(CASE WHEN X.M_id !=803 AND X.M_active='true' AND X.M_delete is null THEN X.ID END) AS \"pending_transfer_out\", COUNT(CASE WHEN X.P_id != 882 AND X.P_active='true' AND X.P_delete is null THEN X.ID END) AS Pending_disposition, COUNT(CASE WHEN X.RD_active='true' AND X.RD_delete is null THEN X.ID END) AS Redeploys, COUNT(CASE WHEN X.E_id = 820 AND X.E_active='true' AND X.E_delete is null THEN X.ID END) AS e_wastes FROM (SELECT DISTINCT inventories.id AS ID , inventories.details -> 'destination_code' AS RPA_Site_Code, vendor_returns.status_id AS V_id, vendor_returns.is_active AS V_active, vendor_returns.deleted_at AS V_delete, insurances.status_id AS I_id, insurances.is_active AS I_active, insurances.deleted_at AS I_delete, repairs.status_id AS R_id, repairs.is_active AS R_active, repairs.deleted_at AS R_delete, replacements.status_id AS RP_id, replacements.is_active AS RP_active, replacements.deleted_at AS RP_delete, liquidations.status_id AS L_id, liquidations.is_active AS L_active, liquidations.deleted_at AS L_delete, markdowns.status_id AS M_id, markdowns.is_active AS M_active, markdowns.deleted_at AS M_delete, pending_dispositions.status_id AS P_id, pending_dispositions.is_active AS P_active, pending_dispositions.deleted_at AS P_delete, e_wastes.status_id AS E_id, e_wastes.is_active AS E_active, e_wastes.deleted_at AS E_delete, redeploys.status_id AS RD_id, redeploys.is_active AS RD_active, redeploys.deleted_at AS RD_delete from public.inventories LEFT JOIN public.vendor_returns ON inventories.id = vendor_returns.inventory_id LEFT JOIN public.insurances ON inventories.id= insurances.inventory_id LEFT JOIN public.repairs ON inventories.id = repairs.inventory_id LEFT JOIN public.replacements ON inventories.id = replacements.inventory_id LEFT JOIN public.liquidations ON inventories.id = liquidations.inventory_id LEFT JOIN public.markdowns ON inventories.id = markdowns.inventory_id LEFT JOIN public.e_wastes ON inventories.id= e_wastes.inventory_id LEFT JOIN public.pending_dispositions ON inventories.id = pending_dispositions.inventory_id LEFT JOIN public.redeploys ON inventories.id = redeploys.inventory_id LEFT JOIN public.client_sku_masters ON inventories.sku_code =  client_sku_masters.code WHERE client_sku_masters.own_label = false ) X GROUP BY X.RPA_Site_Code")
      sql.each do |value|
        brand_manager_data << value
      end

      sql = ActiveRecord::Base.connection.execute("SELECT  X.RPA_Site_Code, COUNT(CASE WHEN X.V_active='true' AND X.V_id!=700 AND X.V_id != 733 AND X.V_id !=701 AND X.V_delete is null THEN X.ID END) AS \"Brand_call_log\", COUNT(CASE WHEN X.V_id = '700' OR X.V_id = '701' AND X.V_active='true' AND X.V_delete is null THEN X.ID END) as rtv, COUNT(CASE WHEN X.I_id != 748 AND X.I_active='true' AND X.I_delete is null THEN X.ID END) AS Insurance, COUNT(CASE WHEN X.R_active='true' AND X.R_delete is null THEN X.ID END ) AS Repair, COUNT(CASE WHEN X.RP_id != 788 AND X.RP_active='true' AND X.RP_delete is null THEN X.ID END) AS Replacement, COUNT(CASE WHEN X.L_active='true' AND X.L_delete is null THEN X.ID END ) AS Liquidation, COUNT(CASE WHEN X.M_id !=803 AND X.M_active='true' AND X.M_delete is null THEN X.ID END) AS \"pending_transfer_out\", COUNT(CASE WHEN X.P_id != 882 AND X.P_active='true' AND X.P_delete is null THEN X.ID END) AS Pending_disposition, COUNT(CASE WHEN X.RD_active='true' AND X.RD_delete is null THEN X.ID END) AS Redeploys, COUNT(CASE WHEN X.E_id = 820 AND X.E_active='true' AND X.E_delete is null THEN X.ID END) AS e_wastes FROM (SELECT DISTINCT inventories.id AS ID , inventories.details -> 'destination_code' AS RPA_Site_Code, vendor_returns.status_id AS V_id, vendor_returns.is_active AS V_active, vendor_returns.deleted_at AS V_delete, insurances.status_id AS I_id, insurances.is_active AS I_active, insurances.deleted_at AS I_delete, repairs.status_id AS R_id, repairs.is_active AS R_active, repairs.deleted_at AS R_delete, replacements.status_id AS RP_id, replacements.is_active AS RP_active, replacements.deleted_at AS RP_delete, liquidations.status_id AS L_id, liquidations.is_active AS L_active, liquidations.deleted_at AS L_delete, markdowns.status_id AS M_id, markdowns.is_active AS M_active, markdowns.deleted_at AS M_delete, pending_dispositions.status_id AS P_id, pending_dispositions.is_active AS P_active, pending_dispositions.deleted_at AS P_delete, e_wastes.status_id AS E_id, e_wastes.is_active AS E_active, e_wastes.deleted_at AS E_delete, redeploys.status_id AS RD_id, redeploys.is_active AS RD_active, redeploys.deleted_at AS RD_delete from public.inventories LEFT JOIN public.vendor_returns ON inventories.id = vendor_returns.inventory_id LEFT JOIN public.insurances ON inventories.id= insurances.inventory_id LEFT JOIN public.repairs ON inventories.id = repairs.inventory_id LEFT JOIN public.replacements ON inventories.id = replacements.inventory_id LEFT JOIN public.liquidations ON inventories.id = liquidations.inventory_id LEFT JOIN public.markdowns ON inventories.id = markdowns.inventory_id LEFT JOIN public.e_wastes ON inventories.id= e_wastes.inventory_id LEFT JOIN public.pending_dispositions ON inventories.id = pending_dispositions.inventory_id LEFT JOIN public.redeploys ON inventories.id = redeploys.inventory_id LEFT JOIN public.client_sku_masters ON inventories.sku_code =  client_sku_masters.code WHERE client_sku_masters.own_label = true ) X GROUP BY X.RPA_Site_Code")
      sql.each do |value|
        brand_manager_ol_data << value
      end

      file_csv = CSV.generate do |csv|
        csv << ["Brand"]
        csv << ["Manager", "RPA Site", "Region", "Brand Call Log",  "RTV", "Insurance", "Repair", "Replacement", "Redeploy", "Liquidation", "Pending Transfer Out", "Pending Disposition", "E- waste", "Total"]

        column_count = 0
        brand_manager_data.each do |brand_manager|
          total = brand_manager["Brand_call_log"].to_i+ brand_manager["rtv"].to_i + brand_manager["insurance"].to_i + brand_manager["repair"].to_i + brand_manager["replacement"].to_i + brand_manager["liquidation"].to_i + brand_manager["pending_transfer_out"].to_i + brand_manager["pending_disposition"].to_i + brand_manager["e_wastes"].to_i + brand_manager["redeploys"].to_i 
          column_count += total
          csv << [brand_manager["store"], brand_manager["rpa_site_code"], "", brand_manager["Brand_call_log"], brand_manager["rtv"], brand_manager["insurance"], brand_manager["repair"], brand_manager["replacement"], brand_manager["redeploys"], brand_manager["liquidation"], brand_manager["pending_transfer_out"], brand_manager["pending_disposition"], brand_manager["e_wastes"], total]
        end

        brand_call_log_count = brand_manager_data.select{|i| i['Brand_call_log'].present?}.inject(0) {|sum, hash| sum + hash["Brand_call_log"]}
        rtv_count = brand_manager_data.select{|i| i['rtv'].present?}.inject(0) {|sum, hash| sum + hash["rtv"]}
        insurance_count = brand_manager_data.select{|i| i['insurance'].present?}.inject(0) {|sum, hash| sum + hash["insurance"]}
        repair_count = brand_manager_data.select{|i| i['repair'].present?}.inject(0) {|sum, hash| sum + hash["repair"]}
        replacement_count = brand_manager_data.select{|i| i['replacement'].present?}.inject(0) {|sum, hash| sum + hash["replacement"]}
        redeploy_count = brand_manager_data.select{|i| i['redeploys'].present?}.inject(0) {|sum, hash| sum + hash["redeploys"]}
        liquidation_count = brand_manager_data.select{|i| i['liquidation'].present?}.inject(0) {|sum, hash| sum + hash["liquidation"]}
        markdown_count = brand_manager_data.select{|i| i['pending_transfer_out'].present?}.inject(0) {|sum, hash| sum + hash["pending_transfer_out"]}
        pending_disposition_count = brand_manager_data.select{|i| i['pending_disposition'].present?}.inject(0) {|sum, hash| sum + hash["pending_disposition"]}
        e_waste_count = brand_manager_data.select{|i| i['e_wastes'].present?}.inject(0) {|sum, hash| sum + hash["e_wastes"]}
        csv << ["","" ,  'Total', brand_call_log_count, rtv_count, insurance_count, repair_count, replacement_count, redeploy_count, liquidation_count, markdown_count, pending_disposition_count, e_waste_count, column_count]

        csv << ["OL"]
        csv << []

        csv << ["Manager", "RPA Site", "Region", "Brand Call Log", "RTV", "Insurance", "Repair", "Replacement", "Redeploy", "Liquidation", "Pending Transfer Out", "Pending Disposition", "E- waste", "Total"]

        column_count = 0
        brand_manager_ol_data.each do |brand_manager_ol|
          total = brand_manager_ol["Brand_call_log"].to_i+ brand_manager_ol["rtv"].to_i + brand_manager_ol["insurance"].to_i + brand_manager_ol["repair"].to_i + brand_manager_ol["replacement"].to_i + brand_manager_ol["liquidation"].to_i + brand_manager_ol["pending_transfer_out"].to_i + brand_manager_ol["pending_disposition"].to_i + brand_manager_ol["e_wastes"].to_i + brand_manager_ol["redeploys"].to_i 

          column_count += total
          csv << [brand_manager_ol["store"], brand_manager_ol["rpa_site_code"], "", brand_manager_ol["Brand_call_log"], brand_manager_ol["rtv"], brand_manager_ol["insurance"], brand_manager_ol["repair"], brand_manager_ol["replacement"], brand_manager_ol["redeploys"], brand_manager_ol["liquidation"], brand_manager_ol["pending_transfer_out"], brand_manager_ol["pending_disposition"], brand_manager_ol["e_wastes"], total]
        end
        brand_call_log_count = brand_manager_ol_data.select{|i| i['Brand_call_log'].present?}.inject(0) {|sum, hash| sum + hash["Brand_call_log"]}
        rtv_count = brand_manager_ol_data.select{|i| i['rtv'].present?}.inject(0) {|sum, hash| sum + hash["rtv"]}
        insurance_count = brand_manager_ol_data.select{|i| i['insurance'].present?}.inject(0) {|sum, hash| sum + hash["insurance"]}
        repair_count = brand_manager_ol_data.select{|i| i['repair'].present?}.inject(0) {|sum, hash| sum + hash["repair"]}
        replacement_count = brand_manager_ol_data.select{|i| i['replacement'].present?}.inject(0) {|sum, hash| sum + hash["replacement"]}
        redeploy_count = brand_manager_data.select{|i| i['redeploys'].present?}.inject(0) {|sum, hash| sum + hash["redeploys"]}
        liquidation_count = brand_manager_ol_data.select{|i| i['liquidation'].present?}.inject(0) {|sum, hash| sum + hash["liquidation"]}
        markdown_count = brand_manager_ol_data.select{|i| i['pending_transfer_out'].present?}.inject(0) {|sum, hash| sum + hash["pending_transfer_out"]}
        pending_disposition_count = brand_manager_ol_data.select{|i| i['pending_disposition'].present?}.inject(0) {|sum, hash| sum + hash["pending_disposition"]}
        e_waste_count = brand_manager_ol_data.select{|i| i['e_wastes'].present?}.inject(0) {|sum, hash| sum + hash["e_wastes"]}
        csv << ["","" ,  'Total', brand_call_log_count, rtv_count, insurance_count, repair_count, replacement_count, redeploy_count, liquidation_count, markdown_count, pending_disposition_count, e_waste_count, column_count]
      end

      amazon_s3 = Aws::S3::Resource.new(region: Rails.application.credentials.aws_s3_region, access_key_id: Rails.application.credentials.access_key_id, secret_access_key: Rails.application.credentials.secret_access_key)

      bucket = Rails.application.credentials.aws_bucket

      time = Time.now.strftime("%F %H:%M:%S").to_s.tr('-', '')

      file_name = "brand_manager_report_#{time.parameterize.underscore}"

      obj = amazon_s3.bucket(bucket).object("uploads/daily_reports/#{file_name}.csv")

      obj.put(body: file_csv, acl: 'public-read', content_disposition: 'attachment', content_type: 'text/csv')

      url = obj.public_url
      
      return url

    end

    def self.get_overall_rpa_inv_report
      overall_rpa_inv_data = []

      sql = ActiveRecord::Base.connection.execute("SELECT X.RPA_Site, X.STR_Name, COUNT(CASE WHEN Date_diff <= 30  THEN X.id END ) AS \"0-30\", COUNT(CASE WHEN Date_diff >= 31 AND Date_diff <=45 THEN X.id END )AS \"31-45\", COUNT(CASE WHEN Date_diff >= 46 AND Date_diff <=60 THEN X.id END ) AS \"46-60\", COUNT(CASE WHEN Date_diff >= 61 AND Date_diff <=90 THEN X.id END ) AS \"61-90\", COUNT(CASE WHEN Date_diff >= 90 THEN X.id END)  AS \"90+\"FROM (SELECT inventories.id,inventories.details->'destination_code' AS RPA_Site,distribution_centers.name as STR_Name, DATE_PART('day', now() - inventories.created_at) AS Date_diff FROM public.inventories LEFT JOIN public.distribution_centers ON distribution_centers.id = inventories.distribution_center_id WHERE inventories.status!= 'Pending GRN' AND inventories.status!= 'Closed Successfully'AND inventories.deleted_at is null) X GROUP BY X.RPA_Site,X.STR_Name")
      sql.each do |value|
        overall_rpa_inv_data << value
      end

      file_csv = CSV.generate do |csv|
        csv << ["STR Code", "STR Name", "0-30 days", "31-45 days", "46-60 days", "61-90 days", ">90 days", "Total"]
        
        column_count = 0
        overall_rpa_inv_data.each do |overall_rpa_inv| 
          total = overall_rpa_inv["0-30"].to_i + overall_rpa_inv["31-45"].to_i + overall_rpa_inv["46-60"].to_i + overall_rpa_inv["61-90"].to_i + overall_rpa_inv["90+"].to_i
          column_count += total
          csv << [overall_rpa_inv["rpa_site"], overall_rpa_inv["str_name"], overall_rpa_inv["0-30"], overall_rpa_inv["31-45"], overall_rpa_inv["46-60"], overall_rpa_inv["61-90"], overall_rpa_inv["90+"], total]
        end

        zero_to_thirty_count = overall_rpa_inv_data.select{|i| i['0-30'].present?}.inject(0) {|sum, hash| sum + hash["0-30"]}
        fourty_five_count = overall_rpa_inv_data.select{|i| i['31-45'].present?}.inject(0) {|sum, hash| sum + hash["31-45"]}
        sixty_count = overall_rpa_inv_data.select{|i| i['46-60'].present?}.inject(0) {|sum, hash| sum + hash["46-60"]}
        ninty_count = overall_rpa_inv_data.select{|i| i['61-90'].present?}.inject(0) {|sum, hash| sum + hash["61-90"]}
        ninty_plus_count = overall_rpa_inv_data.select{|i| i['90+'].present?}.inject(0) {|sum, hash| sum + hash['90+']}
        csv << ["", 'Total', zero_to_thirty_count, fourty_five_count, sixty_count, ninty_count, ninty_plus_count, column_count]
      end

      amazon_s3 = Aws::S3::Resource.new(region: Rails.application.credentials.aws_s3_region, access_key_id: Rails.application.credentials.access_key_id, secret_access_key: Rails.application.credentials.secret_access_key)

      bucket = Rails.application.credentials.aws_bucket

      time = Time.now.strftime("%F %H:%M:%S").to_s.tr('-', '')

      file_name = "overall_rpa_inv_report_#{time.parameterize.underscore}"

      obj = amazon_s3.bucket(bucket).object("uploads/daily_reports/#{file_name}.csv")

      obj.put(body: file_csv, acl: 'public-read', content_disposition: 'attachment', content_type: 'text/csv')

      url = obj.public_url
      
      return url

    end

    def self.get_month
      current_month  = Time.now.month
      months = (current_month+1..12).to_a
      current_month.times {|r| months << r+1}
      updated_months = []
      months.each do |m|
        if m.to_i > current_month.to_i
          updated_months << "#{Date::MONTHNAMES[m]}-#{(Date.today.year) - 1 % 100}"
        else
          updated_months << "#{Date::MONTHNAMES[m]}-#{(Date.today.year) % 100}"
        end
      end
      return updated_months
    end

    def self.get_brand_more_than_ninty_report
      brand_more_than_ninty_days_data = []

      sql = ActiveRecord::Base.connection.execute("SELECT X.RPA_Site,X.STR_Name, COUNT(CASE WHEN X.month = 9 and X.year=2020 and X.Date_diff > 90 THEN X.id END ) AS \"September-20\", COUNT(CASE WHEN X.month = 10 and X.year=2020 and X.Date_diff > 90 THEN X.id END )AS \"October-20\", COUNT(CASE WHEN X.month = 11 and X.year=2020 and X.Date_diff > 90 THEN X.id END) AS \"November-20\", COUNT(CASE WHEN X.month = 12 and X.year=2020 and X.Date_diff > 90 THEN X.id END) AS \"December-20\", COUNT(CASE WHEN X.month = 1 and X.year=2021 and X.Date_diff > 90 THEN X.id END ) AS \"January-21\", COUNT(CASE WHEN X.month = 2 and X.year=2021 and X.Date_diff > 90 THEN X.id END ) AS \"February-21\", COUNT(CASE WHEN X.month = 3 and X.year=2021 and X.Date_diff > 90 THEN X.id END) AS \"March-21\", COUNT(CASE WHEN X.month = 4 and X.year=2021 and X.Date_diff > 90 THEN X.id END ) AS \"April-21\", COUNT(CASE WHEN X.month = 5 and X.year=2021 and X.Date_diff > 90 THEN X.id END ) AS \"May-21\", COUNT(CASE WHEN X.month = 6 and X.year=2021 and X.Date_diff > 90 THEN X.id END) AS \"June-21\", COUNT(CASE WHEN X.month = 7 and X.year=2021 and X.Date_diff > 90 THEN X.id END )AS \"July-21\", COUNT(CASE WHEN X.month = 8 and X.year=2021 and X.Date_diff > 90 THEN X.id END) AS \"August-21\"FROM (SELECT inventories.id,inventories.details->'destination_code' AS RPA_Site,distribution_centers.name as STR_Name, DATE_PART('day', now() - inventories.created_at) AS Date_diff ,DATE_PART('YEAR' ,inventories.created_at) AS year, DATE_PART('MONTH' ,inventories.created_at) AS month FROM public.inventories LEFT JOIN public.distribution_centers ON distribution_centers.id = inventories.distribution_center_id LEFT JOIN public.client_sku_masters ON inventories.sku_code = client_sku_masters.code WHERE inventories.status!= 'Pending GRN' AND inventories.status!= 'Closed Successfully'AND inventories.deleted_at is null AND client_sku_masters.own_label = false) X GROUP BY X.RPA_Site,X.STR_Name")
      sql.each do |value|
        brand_more_than_ninty_days_data << value
      end

      file_csv = CSV.generate do |csv|
        month_year = self.get_month
        csv << ["STR Code", "STR Name", month_year, "Total"].flatten
        # csv << ["STR Code", "STR Name", 'August-20', 'September-20', 'October-20', 'November-20', 'December-20', 'January-21', 'Febuary-21', 'March-21', 'Aprail-21', 'May-21', 'June-21' ,'July-21', "Total"]

        column_count = 0
        dynamic_value = []
        brand_more_than_ninty_days_data.each do |brand_data|
          val = []
          month_year.each do |m|
            month = "#{m.split('-')[0]}-#{m.split('-')[1].last(2)}" 
            val << brand_data[month]
          end
          total = brand_data["January-21"].to_i + brand_data["February-21"].to_i + brand_data["March-21"].to_i + brand_data["April-21"].to_i + brand_data["May-21"].to_i + brand_data["June-21"].to_i + brand_data["July-21"].to_i + brand_data["August-20"].to_i + brand_data["September-20"].to_i + brand_data["October-20"].to_i + brand_data["November-20"].to_i + brand_data["December-20"].to_i
          column_count += total
          csv << [brand_data["rpa_site"], brand_data["str_name"], val, total].flatten
        end

        jan_count = brand_more_than_ninty_days_data.select{|i| i['January-21'].present?}.inject(0) {|sum, hash| sum + hash["January-21"]}
        feb_count = brand_more_than_ninty_days_data.select{|i| i['February-21'].present?}.inject(0) {|sum, hash| sum + hash["February-21"]}
        mar_count = brand_more_than_ninty_days_data.select{|i| i['March-21'].present?}.inject(0) {|sum, hash| sum + hash["March-21"]}
        apr_count = brand_more_than_ninty_days_data.select{|i| i['April-21'].present?}.inject(0) {|sum, hash| sum + hash["April-21"]}
        may_count = brand_more_than_ninty_days_data.select{|i| i['May-21'].present?}.inject(0) {|sum, hash| sum + hash["May-21"]}
        jun_count = brand_more_than_ninty_days_data.select{|i| i['June-21'].present?}.inject(0) {|sum, hash| sum + hash["June-21"]}
        jul_count = brand_more_than_ninty_days_data.select{|i| i['July-21'].present?}.inject(0) {|sum, hash| sum + hash["July-21"]}
        sep_count = brand_more_than_ninty_days_data.select{|i| i['September-20'].present?}.inject(0) {|sum, hash| sum + hash["September-20"]}
        oct_count = brand_more_than_ninty_days_data.select{|i| i['October-20'].present?}.inject(0) {|sum, hash| sum + hash["October-20"]}
        nov_count = brand_more_than_ninty_days_data.select{|i| i['November-20'].present?}.inject(0) {|sum, hash| sum + hash["November-20"]}
        dec_count = brand_more_than_ninty_days_data.select{|i| i['December-20'].present?}.inject(0) {|sum, hash| sum + hash["December-20"]}

        csv << ["", "Total", sep_count, oct_count, nov_count, dec_count, jan_count, feb_count, mar_count, apr_count, may_count, jun_count, jul_count, column_count]
      end

      amazon_s3 = Aws::S3::Resource.new(region: Rails.application.credentials.aws_s3_region, access_key_id: Rails.application.credentials.access_key_id, secret_access_key: Rails.application.credentials.secret_access_key)

      bucket = Rails.application.credentials.aws_bucket

      time = Time.now.strftime("%F %H:%M:%S").to_s.tr('-', '')

      file_name = "brand_more_than_ninty_days_report_#{time.parameterize.underscore}"

      obj = amazon_s3.bucket(bucket).object("uploads/daily_reports/#{file_name}.csv")

      obj.put(body: file_csv, acl: 'public-read', content_disposition: 'attachment', content_type: 'text/csv')

      url = obj.public_url
      
      return url
    end

    def self.get_ol_more_than_ninty_report
      ol_more_than_ninty_days_data = []

      sql = ActiveRecord::Base.connection.execute("SELECT X.RPA_Site,X.STR_Name, COUNT(CASE WHEN X.month = 9 and X.year=2020 and X.Date_diff > 90 THEN X.id END ) AS \"September-20\", COUNT(CASE WHEN X.month = 10 and X.year=2020 and X.Date_diff > 90 THEN X.id END )AS \"October-20\", COUNT(CASE WHEN X.month = 11 and X.year=2020 and X.Date_diff > 90 THEN X.id END) AS \"November-20\", COUNT(CASE WHEN X.month = 12 and X.year=2020 and X.Date_diff > 90 THEN X.id END) AS \"December-20\", COUNT(CASE WHEN X.month = 1 and X.year=2021 and X.Date_diff > 90 THEN X.id END ) AS \"January-21\", COUNT(CASE WHEN X.month = 2 and X.year=2021 and X.Date_diff > 90 THEN X.id END ) AS \"February-21\", COUNT(CASE WHEN X.month = 3 and X.year=2021 and X.Date_diff > 90 THEN X.id END) AS \"March-21\", COUNT(CASE WHEN X.month = 4 and X.year=2021 and X.Date_diff > 90 THEN X.id END ) AS \"April-21\", COUNT(CASE WHEN X.month = 5 and X.year=2021 and X.Date_diff > 90 THEN X.id END ) AS \"May-21\", COUNT(CASE WHEN X.month = 6 and X.year=2021 and X.Date_diff > 90 THEN X.id END) AS \"June-21\", COUNT(CASE WHEN X.month = 7 and X.year=2021 and X.Date_diff > 90 THEN X.id END )AS \"July-21\", COUNT(CASE WHEN X.month = 8 and X.year=2021 and X.Date_diff > 90 THEN X.id END) AS \"August-21\"FROM (SELECT inventories.id,inventories.details->'destination_code' AS RPA_Site,distribution_centers.name as STR_Name, DATE_PART('day', now() - inventories.created_at) AS Date_diff ,DATE_PART('YEAR' ,inventories.created_at) AS year, DATE_PART('MONTH' ,inventories.created_at) AS month FROM public.inventories LEFT JOIN public.distribution_centers ON distribution_centers.id = inventories.distribution_center_id LEFT JOIN public.client_sku_masters ON inventories.sku_code = client_sku_masters.code WHERE inventories.status!= 'Pending GRN' AND inventories.status!= 'Closed Successfully'AND inventories.deleted_at is null AND client_sku_masters.own_label = true) X GROUP BY X.RPA_Site,X.STR_Name")
      sql.each do |value|
        ol_more_than_ninty_days_data << value
      end

      file_csv = CSV.generate do |csv|
        month_year = self.get_month
        csv << ["STR Code", "STR Name", month_year, "Total"].flatten
        
        # csv << ["STR Code", "STR Name", 'August-20', 'September-20', 'October-20', 'November-20', 'December-20', 'January-21', 'Febuary-21', 'March-21', 'Aprail-21', 'May-21', 'June-21' ,'July-21', "Total"]
        
        column_count = 0
        dynamic_val = []
        ol_more_than_ninty_days_data.each do |ol_data|
          val = []
          month_year.each do |m|
            month = "#{m.split('-')[0]}-#{m.split('-')[1].last(2)}" 
            val << ol_data[month]
          end
          total = ol_data["January-21"].to_i + ol_data["February-21"].to_i + ol_data["March-21"].to_i + ol_data["April-21"].to_i + ol_data["May-21"].to_i + ol_data["June-21"].to_i + ol_data["July-21"].to_i + ol_data["August-20"].to_i + ol_data["September-20"].to_i + ol_data["October-20"].to_i + ol_data["November-20"].to_i + ol_data["December-20"].to_i
          column_count += total
          csv << [ol_data["rpa_site"], ol_data["str_name"], val, total].flatten
        end
      end

      amazon_s3 = Aws::S3::Resource.new(region: Rails.application.credentials.aws_s3_region, access_key_id: Rails.application.credentials.access_key_id, secret_access_key: Rails.application.credentials.secret_access_key)

      bucket = Rails.application.credentials.aws_bucket

      time = Time.now.strftime("%F %H:%M:%S").to_s.tr('-', '')

      file_name = "ol_more_than_ninty_days_report_#{time.parameterize.underscore}"

      obj = amazon_s3.bucket(bucket).object("uploads/daily_reports/#{file_name}.csv")

      obj.put(body: file_csv, acl: 'public-read', content_disposition: 'attachment', content_type: 'text/csv')

      url = obj.public_url
      
      return url
    end

    def self.brand_wise_rpa_report
      brand_wise_rpa_data = []

      sql = ActiveRecord::Base.connection.execute("SELECT X.Brand, COUNT(CASE WHEN X.month = 9 and X.year=2020  THEN X.id END ) AS \"September-20\", COUNT(CASE WHEN X.month = 10 and X.year=2020  THEN X.id END )AS \"October-20\", COUNT(CASE WHEN X.month = 11 and X.year=2020  THEN X.id END) AS \"November-20\", COUNT(CASE WHEN X.month = 12 and X.year=2020  THEN X.id END) AS \"December-20\", COUNT(CASE WHEN X.month = 1 and X.year=2021  THEN X.id END ) AS \"January-21\", COUNT(CASE WHEN X.month = 2 and X.year=2021  THEN X.id END ) AS \"February-21\", COUNT(CASE WHEN X.month = 3 and X.year=2021 THEN X.id END) AS \"March-21\", COUNT(CASE WHEN X.month = 4 and X.year=2021  THEN X.id END ) AS \"April-21\", COUNT(CASE WHEN X.month = 5 and X.year=2021  THEN X.id END ) AS \"May-21\", COUNT(CASE WHEN X.month = 6 and X.year=2021  THEN X.id END) AS \"June-21\", COUNT(CASE WHEN X.month = 7 and X.year=2021  THEN X.id END )AS \"July-21\", COUNT(CASE WHEN X.month = 8 and X.year=2021  THEN X.id END) AS \"August-21\"FROM (SELECT inventories.id,inventories.details->'brand' AS Brand, DATE_PART('day', now() - inventories.created_at) AS Date_diff ,DATE_PART('YEAR' ,inventories.created_at) AS year, DATE_PART('MONTH' ,inventories.created_at) AS month FROM public.inventories WHERE inventories.status!= 'Pending GRN' AND inventories.status!= 'Closed Successfully'AND inventories.deleted_at is null ) X GROUP BY X.Brand ORDER BY X.Brand")
      sql.each do |value|
        brand_wise_rpa_data << value
      end
      file_csv = CSV.generate do |csv|
         month_year = self.get_month
         csv << ["Brand", get_month, "Total"].flatten
          # csv << ["Brand", 'August-20', 'September-20', 'October-20', 'November-20', 'December-20', 'January-21', 'Febuary-21', 'March-21', 'Aprail-21', 'May-21', 'June-21' ,'July-21', "Total"]

        column_count = 0
        dynamic_value = []
        brand_wise_rpa_data.each do |rpa_data|
          val = []
          month_year.each do |m|
            month = "#{m.split('-')[0]}-#{m.split('-')[1].last(2)}" 
            val << rpa_data[month]
          end
          total = rpa_data["January-21"].to_i + rpa_data["February-21"].to_i + rpa_data["March-21"].to_i + rpa_data["April-21"].to_i + rpa_data["May-21"].to_i + rpa_data["June-21"].to_i + rpa_data["July-21"].to_i + rpa_data["August-20"].to_i + rpa_data["September-20"].to_i + rpa_data["October-20"].to_i + rpa_data["November-20"].to_i + rpa_data["December-20"].to_i
          column_count += total
          csv << [rpa_data["brand"], val, total].flatten
        end

        jan_count = brand_wise_rpa_data.select{|i| i['January-21'].present?}.inject(0) {|sum, hash| sum + hash["January-21"]}
        feb_count = brand_wise_rpa_data.select{|i| i['February-21'].present?}.inject(0) {|sum, hash| sum + hash["February-21"]}
        mar_count = brand_wise_rpa_data.select{|i| i['March-21'].present?}.inject(0) {|sum, hash| sum + hash["March-21"]}
        apr_count = brand_wise_rpa_data.select{|i| i['April-21'].present?}.inject(0) {|sum, hash| sum + hash["April-21"]}
        may_count = brand_wise_rpa_data.select{|i| i['May-21'].present?}.inject(0) {|sum, hash| sum + hash["May-21"]}
        jun_count = brand_wise_rpa_data.select{|i| i['June-21'].present?}.inject(0) {|sum, hash| sum + hash["June-21"]}
        jul_count = brand_wise_rpa_data.select{|i| i['July-21'].present?}.inject(0) {|sum, hash| sum + hash["July-21"]}
        sep_count = brand_wise_rpa_data.select{|i| i['September-20'].present?}.inject(0) {|sum, hash| sum + hash["September-20"]}
        oct_count = brand_wise_rpa_data.select{|i| i['October-20'].present?}.inject(0) {|sum, hash| sum + hash["October-20"]}
        nov_count = brand_wise_rpa_data.select{|i| i['November-20'].present?}.inject(0) {|sum, hash| sum + hash["November-20"]}
        dec_count = brand_wise_rpa_data.select{|i| i['December-20'].present?}.inject(0) {|sum, hash| sum + hash["December-20"]}

        csv << ["Total", sep_count, oct_count, nov_count, dec_count, jan_count, feb_count, mar_count, apr_count, may_count, jun_count, jul_count, column_count]
      end

      amazon_s3 = Aws::S3::Resource.new(region: Rails.application.credentials.aws_s3_region, access_key_id: Rails.application.credentials.access_key_id, secret_access_key: Rails.application.credentials.secret_access_key)

      bucket = Rails.application.credentials.aws_bucket

      time = Time.now.strftime("%F %H:%M:%S").to_s.tr('-', '')

      file_name = "brand_wise_rpa_report_#{time.parameterize.underscore}"

      obj = amazon_s3.bucket(bucket).object("uploads/daily_reports/#{file_name}.csv")

      obj.put(body: file_csv, acl: 'public-read', content_disposition: 'attachment', content_type: 'text/csv')

      url = obj.public_url
      
      return url

    end

    def self.rpa_in_out_tracker
      week_number = 52
      closed_status_id = LookupValue.where(code: Rails.application.credentials.inventory_status_warehouse_closed_successfully).last.id
      inventory_hash = {}
      inventory_status_warehouse_pending_grn = LookupValue.where("code = ?", Rails.application.credentials.inventory_status_warehouse_pending_grn).first
        opened_inventories = Inventory.where("is_forward = ? and status_id != ?", false, inventory_status_warehouse_pending_grn.try(:id))

      (1..365).to_a.in_groups_of(7).reject {|e| e.include?(nil)}.each_with_index do |week, ind|
        
        key = "week-#{week_number} / #{(Time.now - (week[0]-1).days).strftime("%d/%b")}"
        from_date = Date.today.end_of_day - week[6].days
        to_date = (ind == 0 ? (Date.today.beginning_of_day) : (Date.today.beginning_of_day - week[0].days))
        inventory_hash[key] = {}

        inventory_closed_status = LookupValue.where(code: Rails.application.credentials.inventory_status_warehouse_closed_successfully).last
        closed_inventories = Inventory.where(is_forward: false, status_id: inventory_closed_status.try(:id))
        
        inventory_hash[key]["other_inventories"] = opened_inventories.where(created_at: (from_date.beginning_of_day)..(to_date.end_of_day)).select{|i| !["R", "A", "B", "D"].include?(i.details["source_code"].split("")[0])}

        inventory_hash[key]["rp_site_inventories"] = opened_inventories.where(created_at: (from_date.beginning_of_day)..(to_date.end_of_day)).select{|i| ["R", "B"].include?(i.details["source_code"].split("")[0])}

        inventory_hash[key]["store_inventories"] = opened_inventories.where(created_at: (from_date.beginning_of_day)..(to_date.end_of_day)).select{|i|i.details["source_code"].split("")[0] == "A"}

        inventory_hash[key]["dc_inventories"] = opened_inventories.where(created_at: (from_date.beginning_of_day)..(to_date.end_of_day)).select{|i|i.details["source_code"].split("")[0] == "D"}

        inventory_hash[key]["in_transit_inventories"] = opened_inventories.where(created_at: (from_date.beginning_of_day)..(to_date.end_of_day)).select{|i|i.details["issue_type"] == "In-Transit"}

        inventory_hash[key]["excess_inventories"] = opened_inventories.where(created_at: (from_date.beginning_of_day)..(to_date.end_of_day)).select{|i|i.details["issue_type"] == "Excess"}

        inventory_hash[key]["vendor_return"] = closed_inventories.where(disposition: ["RTV", "Brand Call-Log"]).where("inventories.details ->> 'dispatch_complete_date' BETWEEN ? AND ?", from_date.beginning_of_day, to_date.end_of_day + 1.day)

        inventory_hash[key]["transfer_out_closed"] = closed_inventories.joins(:inventory_statuses).where("inventory_statuses.status_id = ? AND inventory_statuses.created_at BETWEEN ? AND ?", closed_status_id, from_date.beginning_of_day, to_date.end_of_day).where(disposition: "Pending Transfer Out")

        inventory_hash[key]["insurance_closed"] = closed_inventories.joins(:inventory_statuses).where("inventory_statuses.status_id = ? AND inventory_statuses.created_at BETWEEN ? AND ?", closed_status_id, from_date.beginning_of_day, to_date.end_of_day).where(disposition: "Insurance")

        inventory_hash[key]["closed_successfully"] = closed_inventories.joins(:inventory_statuses).where("inventory_statuses.status_id = ? AND inventory_statuses.created_at BETWEEN ? AND ?", closed_status_id, from_date.beginning_of_day, to_date.end_of_day).select{|i| ["In-Transit", "Excess"].include?(i.details["issue_type"])}

        inventory_hash[key]["liquidation"] = closed_inventories.joins(:inventory_statuses).where("inventory_statuses.status_id = ? AND inventory_statuses.created_at BETWEEN ? AND ?", closed_status_id, from_date.beginning_of_day, to_date.end_of_day).where(disposition: "Liquidation")

        inventory_hash[key]["redeploy"] = closed_inventories.joins(:inventory_statuses).where("inventory_statuses.status_id = ? AND inventory_statuses.created_at BETWEEN ? AND ?", closed_status_id, from_date.beginning_of_day, to_date.end_of_day).where(disposition: "Redeploy")

        inventory_hash[key]["rpa_to_rpa"] = []
        week_number = week_number - 1
      end


      file_csv = CSV.generate do |csv|
        in_transit_inventories_count = []
        excess_inventories_count = []
        other_inventories_count = []
        dc_inventories_count = []
        store_inventories_count = []
        vendor_return_count = []
        liquidation_count = []
        redeploy_count = []
        rp_site_inventories_count = []
        rpa_to_rpa_count = []
        transfer_out_count = []
        insurance_closed_count = []
        closed_successfully_count = []
        pending_replacement_count = []

        inventory_hash = Hash[inventory_hash.to_a.reverse]
        keys = inventory_hash.map{|t| t[0]}.flatten
        total_inward = []
        total_outward = []
        keys.each_with_index do |key, ind|
          
          other_inventories_count << inventory_hash[key]["other_inventories"].size
          dc_inventories_count <<  inventory_hash[key]["dc_inventories"].size
          rp_site_inventories_count <<  inventory_hash[key]["rp_site_inventories"].size
          store_inventories_count << inventory_hash[key]["store_inventories"].size
          in_transit_inventories_count << inventory_hash[key]["in_transit_inventories"].size
          excess_inventories_count << inventory_hash[key]["excess_inventories"].size

          total_inward << (inventory_hash[key]["other_inventories"].size + inventory_hash[key]["dc_inventories"].size + inventory_hash[key]["store_inventories"].size + inventory_hash[key]["in_transit_inventories"].size + inventory_hash[key]["excess_inventories"].size + inventory_hash[key]["rp_site_inventories"].size )

          vendor_return_count << inventory_hash[key]["vendor_return"].size rescue 0
          transfer_out_count << inventory_hash[key]["transfer_out_closed"].size rescue 0
          insurance_closed_count << inventory_hash[key]["insurance_closed"].size rescue 0
          closed_successfully_count << inventory_hash[key]["closed_successfully"].size rescue 0
          liquidation_count << inventory_hash[key]["liquidation"].size rescue 0
          redeploy_count << inventory_hash[key]["redeploy"].size rescue 0
          rpa_to_rpa_count << inventory_hash[key]["rpa_to_rpa"].size rescue 0

          total_outward << (inventory_hash[key]["vendor_return"].size + inventory_hash[key]["liquidation"].size + inventory_hash[key]["redeploy"].size + inventory_hash[key]["rpa_to_rpa"].size + inventory_hash[key]["transfer_out_closed"].size + inventory_hash[key]["insurance_closed"].size + inventory_hash[key]["closed_successfully"].size) rescue 0

        end
        csv << ["Inward", "PAN India", keys, "Total"].flatten
        csv << ["", "From Store", store_inventories_count, store_inventories_count.sum].flatten
        csv << ["", "From DC", dc_inventories_count, dc_inventories_count.sum].flatten
        csv << ["", "From RP/B Site", rp_site_inventories_count, rp_site_inventories_count.sum].flatten
        csv << ["", "From CCC,SO,IB,Ecom", other_inventories_count, other_inventories_count.sum].flatten
        csv << ["", "Intransit", in_transit_inventories_count, in_transit_inventories_count.sum].flatten
        csv << ["", "Excess", excess_inventories_count, excess_inventories_count.sum].flatten
        csv << ["", "Total Inward",total_inward, total_inward.sum].flatten
        csv << []
        csv << ["Outward", "Vendor Return", vendor_return_count, vendor_return_count.sum].flatten
        csv << ["", "Liquidation", liquidation_count, liquidation_count.sum].flatten
        csv << ["", "DC Redeployment", redeploy_count, redeploy_count.sum].flatten
        csv << ["", "Transfer Out Closed", transfer_out_count, transfer_out_count.sum].flatten
        csv << ["", "Insurance Closed", insurance_closed_count, insurance_closed_count.sum].flatten
        csv << ["", "Closed Successfully", closed_successfully_count, closed_successfully_count.sum].flatten
        csv << ["", "RPA to RPA movement", "", ""].flatten
        csv << ["", "Total Outward",total_outward, total_outward.sum].flatten
      end

      amazon_s3 = Aws::S3::Resource.new(region: Rails.application.credentials.aws_s3_region, access_key_id: Rails.application.credentials.access_key_id, secret_access_key: Rails.application.credentials.secret_access_key)

      bucket = Rails.application.credentials.aws_bucket

      time = Time.now.strftime("%F %H:%M:%S").to_s.tr('-', '')

      file_name = "rpa_in_out_tracker_#{time.parameterize.underscore}"

      obj = amazon_s3.bucket(bucket).object("uploads/daily_reports/#{file_name}.csv")

      obj.put(body: file_csv, acl: 'public-read', content_disposition: 'attachment', content_type: 'text/csv')

      url = obj.public_url
      
      return url
    end

    def self.get_in_transit_report
      status_ids = []
      pending_issue_status =  LookupValue.where(code: Rails.application.credentials.inventory_status_warehouse_pending_issue_resolution).last
      gatepass_inventory_pending_receipt_status =  LookupValue.where("code = ?", Rails.application.credentials.gatepass_inventory_status_pending_receipt).first
      gate_pass_inventories = GatePassInventory.includes(:gate_pass).where("gate_passes.is_forward = ? and gate_pass_inventories.status_id = ?  and gate_passes.status != ? and gate_passes.id is not null", false, gatepass_inventory_pending_receipt_status.id,  "Closed").references(:gate_pass_inventories, :gate_passes)

      inventory_status_warehouse_pending_grn = LookupValue.where("code = ?", Rails.application.credentials.inventory_status_warehouse_pending_grn).first
      status_ids << pending_issue_status.try(:id)
      status_ids << inventory_status_warehouse_pending_grn.try(:id)
      pending_issue_inventories = Inventory.includes(:gate_pass).where("gate_passes.is_forward = ? and inventories.status_id in (?) and gate_passes.status != ?", false, status_ids, "Closed").references(:inventories, :gate_passes)
      
      inventory_hash = {}
      gp_inventory_hash = {}

      inventory_hash["0_to_7_inventories"] = pending_issue_inventories.where(inventories: {created_at: (Date.today.beginning_of_day - 7.days )..(Date.today.end_of_day)}).select{|i| ["R", "B"].include?(i.details["destination_code"].split("")[0])}.select{|i| i.details["issue_type"] == "In-Transit" || i.details["issue_type"] == nil}

      gp_inventory_hash["0_to_7_gp_inventories"] = gate_pass_inventories.includes(:gate_pass).where(gate_passes: {dispatch_date: (Date.today.beginning_of_day - 8.days )..(Date.today.end_of_day)}).select{|i| i.details["proceed_to_grn_without_grading"] != true} 

      inventory_hash["8_to_14_inventories"] = pending_issue_inventories.where(inventories: {created_at: (Date.today.beginning_of_day - 14.days )..(Date.today.end_of_day - 8.days)}).select{|i| ["R", "B"].include?(i.details["destination_code"].split("")[0])}.select{|i| i.details["issue_type"] == "In-Transit" || i.details["issue_type"] == nil}

      gp_inventory_hash["8_to_14_gp_inventories"] = gate_pass_inventories.includes(:gate_pass).where(gate_passes: {dispatch_date: (Date.today.beginning_of_day - 14.days )..(Date.today.end_of_day - 8.days)}).select{|i| i.details["proceed_to_grn_without_grading"] != true}

      inventory_hash["15_to_30_inventories"] = pending_issue_inventories.where(inventories: {created_at: (Date.today.beginning_of_day - 30.days )..(Date.today.end_of_day - 15.days)}).select{|i| ["R", "B"].include?(i.details["destination_code"].split("")[0])}.select{|i| i.details["issue_type"] == "In-Transit" || i.details["issue_type"] == nil}

      gp_inventory_hash["15_to_30_gp_inventories"] = gate_pass_inventories.includes(:gate_pass).where(gate_passes: {dispatch_date: (Date.today.beginning_of_day - 30.days )..(Date.today.end_of_day - 15.days)}).select{|i| i.details["proceed_to_grn_without_grading"] != true}

      inventory_hash["more_than_30_inventories"] = pending_issue_inventories.where("inventories.created_at < ?", (Date.today.beginning_of_day - 30.days )).select{|i| ["R", "B"].include?(i.details["destination_code"].split("")[0])}.select{|i| i.details["issue_type"] == "In-Transit" || i.details["issue_type"] == nil}

      gp_inventory_hash["more_than_30_gp_inventories"] = gate_pass_inventories.includes(:gate_pass).where("gate_passes.dispatch_date < ?", (Date.today.beginning_of_day - 30.days)).select{|i| i.details["proceed_to_grn_without_grading"] != true}

      file_csv = CSV.generate do |csv|
        csv << ["Reciving Site", "Site Name", "0-7 days", "8-14 days", "15-30 days", ">30 days", "Grand Total"]
        
        DistributionCenter.select{|i| ["R", "B"].include?(i.code.split("")[0])}.each do |distribution_center|

          last_week_inv_data = inventory_hash["0_to_7_inventories"].select{|i| i.details["destination_code"] == distribution_center.code}.count

          last_week_gp_data = gp_inventory_hash["0_to_7_gp_inventories"].select{|i| i.distribution_center_id == distribution_center.id}

          last_week_gp_data = last_week_gp_data.pluck(:quantity).sum - last_week_gp_data.pluck(:inwarded_quantity).sum 

          last_week_data = last_week_inv_data + last_week_gp_data

          last_two_week_inv_data = inventory_hash["8_to_14_inventories"].select{|i| i.details["destination_code"] == distribution_center.code}.count
          last_two_week_gp_data = gp_inventory_hash["8_to_14_gp_inventories"].select{|i| i.distribution_center_id == distribution_center.id}

          last_two_week_gp_data = last_two_week_gp_data.pluck(:quantity).sum - last_two_week_gp_data.pluck(:inwarded_quantity).sum 

          last_two_week_data = last_two_week_inv_data + last_two_week_gp_data
          
          last_one_month_inv_data = inventory_hash["15_to_30_inventories"].select{|i| i.details["destination_code"] == distribution_center.code}.count
          last_one_month_gp_data = gp_inventory_hash["15_to_30_gp_inventories"].select{|i| i.distribution_center_id == distribution_center.id}

          last_one_month_gp_data = last_one_month_gp_data.pluck(:quantity).sum - last_one_month_gp_data.pluck(:inwarded_quantity).sum 

          last_one_month_data = last_one_month_inv_data + last_one_month_gp_data

          previous_months_inv_data = inventory_hash["more_than_30_inventories"].select{|i| i.details["destination_code"] == distribution_center.code}.count
          previous_months_gp_data = gp_inventory_hash["more_than_30_gp_inventories"].select{|i| i.distribution_center_id == distribution_center.id}

          previous_months_gp_data = previous_months_gp_data.pluck(:quantity).sum - previous_months_gp_data.pluck(:inwarded_quantity).sum 

          previous_months_data = previous_months_inv_data + previous_months_gp_data

          row_total = last_week_data + last_two_week_data + last_one_month_data + previous_months_data
          code = distribution_center.code
          name = distribution_center.name

          csv << [code, name, last_week_data, last_two_week_data, last_one_month_data, previous_months_data, row_total]
        end
        gp_count_more_than_30_days = gp_inventory_hash["more_than_30_gp_inventories"].select{|i| ["R", "B"].include?(i.distribution_center.code.split("")[0])}
        
        this_week_gp = gp_inventory_hash["0_to_7_gp_inventories"].pluck(:quantity).sum - gp_inventory_hash["0_to_7_gp_inventories"].pluck(:inwarded_quantity).sum
        last_week_gp = gp_inventory_hash["8_to_14_gp_inventories"].pluck(:quantity).sum - gp_inventory_hash["8_to_14_gp_inventories"].pluck(:inwarded_quantity).sum
        last_month_gp = gp_inventory_hash["15_to_30_gp_inventories"].pluck(:quantity).sum - gp_inventory_hash["15_to_30_gp_inventories"].pluck(:inwarded_quantity).sum
        old_gp = gp_count_more_than_30_days.pluck(:quantity).sum - gp_count_more_than_30_days.pluck(:inwarded_quantity).sum

        csv << ["", "Grand Total", inventory_hash["0_to_7_inventories"].count + this_week_gp, inventory_hash["8_to_14_inventories"].count + last_week_gp, inventory_hash["15_to_30_inventories"].count + last_month_gp, inventory_hash["more_than_30_inventories"].count + old_gp]
      end

      amazon_s3 = Aws::S3::Resource.new(region: Rails.application.credentials.aws_s3_region, access_key_id: Rails.application.credentials.access_key_id, secret_access_key: Rails.application.credentials.secret_access_key)

      bucket = Rails.application.credentials.aws_bucket

      time = Time.now.strftime("%F %H:%M:%S").to_s.tr('-', '')

      file_name = "in_transit_report_#{time.parameterize.underscore}"

      obj = amazon_s3.bucket(bucket).object("uploads/daily_reports/#{file_name}.csv")

      obj.put(body: file_csv, acl: 'public-read', content_disposition: 'attachment', content_type: 'text/csv')

      url = obj.public_url
      
      return url
    end

    def self.rpa_sitewise_transfer
      closed_inventories = []
      week_number = 52

      inventory_status_warehouse_pending_grn = LookupValue.where("code = ?", Rails.application.credentials.inventory_status_warehouse_pending_grn).first
        inventories = Inventory.where("is_forward = ? and status_id != ?", false, inventory_status_warehouse_pending_grn.try(:id))

      source_keys = inventories.group_by { |t| t.details['source_code'] }.keys
      source_keys.each do |source_code|      
        inventory_hash = {}
        inventory_hash[source_code] = {}
        (1..365).to_a.in_groups_of(7).reject {|e| e.include?(nil)}.reverse.each_with_index do |week, ind|
          key = "week-#{ind + 1} / #{(Time.now - (week[0]-1).days).strftime("%d/%b")}"
          from_date = Date.today.end_of_day - week[6].days
          to_date = (ind == 51 ? (Date.today.beginning_of_day) : (Date.today.beginning_of_day - week[0].days))
          inventory_hash[source_code][key] = {}
          inventory_hash[source_code][key] = inventories.where(created_at: (from_date.beginning_of_day)..(to_date.end_of_day)).where("details ->> 'source_code' = ?" , source_code).count
        end
        closed_inventories << inventory_hash
      end

      file_csv = CSV.generate do |csv|
        keys = closed_inventories.map{|t| t.keys}.flatten
        weeks = closed_inventories.map{|t| t.values[0].keys}.uniq.flatten
        total_inward = []
        closed_inventories_count = []
        total_outward = []

        csv << ["Region", "Cluster Manager", "Site", "Site Name", "Weekly Average", "Max Value", "Min Value", weeks, "Total"].flatten
        
        total_weekly_count = []
        weekly_average_sum = 0
        max_average_sum = 0
        min_average_sum = 0

        source_keys.each_with_index do |source_code, ind|
          week_values = closed_inventories[ind][source_code].values rescue []
          dc = DistributionCenter.find_by_code(source_code) rescue ""
          manager = dc.users.includes(:roles).where(roles: {code: "warehouse"}).first.full_name rescue ""
          weekly_average = (week_values.inject{ |sum, el| sum + el }.to_f / week_values.size).to_s rescue ""
          weekly_average_sum += weekly_average.to_i
          max_average_sum += week_values.max.to_i
          min_average_sum += week_values.min.to_i
          csv << ["From Store", manager, source_code, dc.name, weekly_average, week_values.max, week_values.min, week_values, week_values.sum].flatten
        end
        
        column_sum = []

        weeks.each do |week|
          count = 0
          source_keys.each_with_index do |source_code, ind|
            count += closed_inventories[ind][source_code][week].to_i
          end
          column_sum << count          
        end

        csv << ["", "", "", "Total", weekly_average_sum, max_average_sum, min_average_sum, column_sum, column_sum.sum].flatten
      end

      amazon_s3 = Aws::S3::Resource.new(region: Rails.application.credentials.aws_s3_region, access_key_id: Rails.application.credentials.access_key_id, secret_access_key: Rails.application.credentials.secret_access_key)

      bucket = Rails.application.credentials.aws_bucket

      time = Time.now.strftime("%F %H:%M:%S").to_s.tr('-', '')

      file_name = "rpa_sources_sitewise_transfer_#{time.parameterize.underscore}"

      obj = amazon_s3.bucket(bucket).object("uploads/daily_reports/#{file_name}.csv")

      obj.put(body: file_csv, acl: 'public-read', content_disposition: 'attachment', content_type: 'text/csv')

      url = obj.public_url
      
      return url
    end


    def self.update_serial_number_to_buckets
      VendorReturn.all.each do |vr|
        vr.serial_number = vr.inventory.serial_number if ((vr.serial_number == "NA" || vr.serial_number.blank?) && (vr.inventory.serial_number != "NA" && vr.inventory.serial_number.present?))
        vr.serial_number2 = vr.inventory.serial_number_2 if ((vr.serial_number2 == "NA" || vr.serial_number2.blank?) && (vr.inventory.serial_number_2 != "NA" && vr.inventory.serial_number_2.blank?))
        vr.save
      end

      Replacement.all.each do |vr|
        vr.serial_number = vr.inventory.serial_number if ((vr.serial_number == "NA" || vr.serial_number.blank?) && (vr.inventory.serial_number != "NA" && vr.inventory.serial_number.present?))
        vr.serial_number_2 = vr.inventory.serial_number_2 if ((vr.serial_number_2 == "NA" || vr.serial_number_2.blank?) && (vr.inventory.serial_number_2 != "NA" && vr.inventory.serial_number_2.blank?))
        vr.save
      end

      Insurance.all.each do |vr|
        vr.serial_number = vr.inventory.serial_number if ((vr.serial_number == "NA" || vr.serial_number.blank?) && (vr.inventory.serial_number != "NA" && vr.inventory.serial_number.present?))
        vr.serial_number_2 = vr.inventory.serial_number_2 if ((vr.serial_number_2 == "NA" || vr.serial_number_2.blank?) && (vr.inventory.serial_number_2 != "NA" && vr.inventory.serial_number_2.blank?))
        vr.save
      end

      Repair.all.each do |vr|
        vr.serial_number = vr.inventory.serial_number if ((vr.serial_number == "NA" || vr.serial_number.blank?) && (vr.inventory.serial_number != "NA" && vr.inventory.serial_number.present?))
        vr.serial_number_2 = vr.inventory.serial_number_2 if ((vr.serial_number_2 == "NA" || vr.serial_number_2.blank?) && (vr.inventory.serial_number_2 != "NA" && vr.inventory.serial_number_2.blank?))
        vr.save
      end

      Liquidation.all.each do |vr|
        vr.serial_number = vr.inventory.serial_number if ((vr.serial_number == "NA" || vr.serial_number.blank?) && (vr.inventory.serial_number != "NA" && vr.inventory.serial_number.present?))
        vr.serial_number_2 = vr.inventory.serial_number_2 if ((vr.serial_number_2 == "NA" || vr.serial_number_2.blank?) && (vr.inventory.serial_number_2 != "NA" && vr.inventory.serial_number_2.blank?))
        vr.save
      end

      Markdown.all.each do |vr|
        vr.serial_number = vr.inventory.serial_number if ((vr.serial_number == "NA" || vr.serial_number.blank?) && (vr.inventory.serial_number != "NA" && vr.inventory.serial_number.present?))
        vr.serial_number_2 = vr.inventory.serial_number_2 if ((vr.serial_number_2 == "NA" || vr.serial_number_2.blank?) && (vr.inventory.serial_number_2 != "NA" && vr.inventory.serial_number_2.blank?))
        vr.save
      end

      EWaste.all.each do |vr|
        vr.serial_number = vr.inventory.serial_number if ((vr.serial_number == "NA" || vr.serial_number.blank?) && (vr.inventory.serial_number != "NA" && vr.inventory.serial_number.present?))
        vr.serial_number_2 = vr.inventory.serial_number_2 if ((vr.serial_number_2 == "NA" || vr.serial_number_2.blank?) && (vr.inventory.serial_number_2 != "NA" && vr.inventory.serial_number_2.blank?))
        vr.save
      end

      Redeploy.all.each do |vr|
        vr.serial_number = vr.inventory.serial_number if ((vr.serial_number == "NA" || vr.serial_number.blank?) && (vr.inventory.serial_number != "NA" && vr.inventory.serial_number.present?))
        vr.serial_number_2 = vr.inventory.serial_number_2 if ((vr.serial_number_2 == "NA" || vr.serial_number_2.blank?) && (vr.inventory.serial_number_2 != "NA" && vr.inventory.serial_number_2.blank?))
        vr.save
      end

    end

  def get_disposition(bucket)
    if LookupValue.where(code: [Rails.application.credentials.dispatch_status_pending_pick_and_pack, Rails.application.credentials.dispatch_status_pending_dispatch, Rails.application.credentials.dispatch_status_completed]).pluck(:id).include?(bucket.try(:status_id))
      bucket.status == "Completed" ? "Dispatched" : "Dispatch"
    else
      disposition
    end
  end

  def get_status(bucket)
    if LookupValue.where(code: [Rails.application.credentials.dispatch_status_pending_pick_and_pack, Rails.application.credentials.dispatch_status_pending_dispatch, Rails.application.credentials.dispatch_status_completed]).pluck(:id).include?(bucket.try(:status_id))
      return bucket.status == "Completed" ? "--" : bucket.status
    end

    case bucket.class.name
      
    when "BrandCallLog"
      return bucket.status&.titleize

    when "VendorReturn"
      if bucket.status == "Pending Dispatch"
        return "Pending Confirmation"
      elsif bucket.status == "Pending Settlement"
        return "Pending Finalisation"
      elsif bucket.status == "Pending Claim"
        return "Pending Call Log"
      elsif bucket.status == "Pending Call Log"
        return "Update Call Log"
      elsif bucket.status == "Pending Brand Inspection"
        return "Pending Inspection"
      elsif ["Pending Brand Resolution", "Pending Brand Approval"].include?(bucket.status)
        return "Pending Brand Resolution"
      else
        return bucket.status
      end

    when "Insurance"
      return bucket.insurance_status&.titleize

    when "Replacement"
      if bucket.status == "Pending Replacement Disposition "
        return "Pending Redeployment"
      elsif bucket.status == "Pending Replacement Approved"
        return 'Pending Replacement'
      else
        return bucket.status
      end

    when "Repair"
      if bucket.status == "Pending Repair Initiation"
        return "Pending Repair Inspection"
      elsif bucket.status == "Pending Repair"
        return "Pending Repair"
      elsif bucket.status == "Pending Redeployment"
        return "Pending Redeployment"
      else
        return bucket.status
      end

    when "Redeploy"
      if bucket.status == "Pending Redeploy Destination"
        return "Pending Redeploy Dispatch"
      else
        return bucket.status
      end
      
    when "Restock"
      if bucket.status == "Pending Restock Destination"
        return "Pending Restock Location"
      elsif bucket.status == "Pending Restock Dispatch"
        return "Dispatch"
      else
        return bucket.status
      end

    when "Liquidation"
      if bucket.status == "Lot Creation"
        return "Pending RFQ"
      elsif bucket.status == "Lot Status"
        return "Pending Billing"
      else
        return bucket.status
      end
    else
      return bucket.status
    end
  end

  def get_closed_status(bucket)
    case bucket.class.name
    when "VendorReturn"
      return 'RTV Closed'
    when "Insurance"
      return 'Insurance Closed'
    when "Liquidation"
      return 'Liquidation Closed'
    when "EWaste"
      return 'E-Waste Closed'
    when "Markdown"
      return 'Transfer Out Closed'
    when "Redeploy"
      return 'Redeploy Closed'
    else
      return bucket.status rescue ''
    end 
  end


  def get_order_date(bucket)
    date = ''
    case bucket.class.name
    when "VendorReturn"
      date = bucket.vendor_return_order.warehouse_orders.last.created_at.strftime("%d/%b/%Y") rescue ''
    when "Insurance"
      date = bucket.insurance_order.warehouse_orders.last.created_at.strftime("%d/%b/%Y") rescue ''
    when "Redeploy"
     date = bucket.redeploy_order.warehouse_orders.last.created_at.strftime("%d/%b/%Y") rescue ''
    when "Markdown"
      date = bucket.markdown_order.warehouse_orders.last.created_at.strftime("%d/%b/%Y") rescue ''
    when "Liquidation"
      date = bucket.liquidation_order.warehouse_orders.last.created_at.strftime("%d/%b/%Y") rescue ''
    end
    return date
  end

  def remarks
    remark = ''
    inv_grading_detail = inventory_grading_details.last.details['final_grading_result'] rescue []
    if inv_grading_detail.present?
      inv_grading_detail.each do |k, value|
        substring = ''
        if k != 'Reason'
          if k == 'Item Condition'
            inv_grading_detail[k].each_with_index do |updated, i|
              substring += "#{k}: #{updated['value']}, "
            end
          elsif k == 'Physical Condition'
            inv_grading_detail[k].each_with_index do |updated, i|
              substring += "#{k}:" if i == 0
              substring += "#{updated['value']}, "
            end
          else
            substring += "#{k}: #{value[0]['value']}" if (value.present? && value[0].present? && value[0]['value'].present?)
          end
          remark += "#{substring} \n "
        end
      end
    end
    return remark
  end

  def physical_remark
    ph_remark = ''
    inv_grading_detail = inventory_grading_details.last.details['final_grading_result'] rescue []
    if inv_grading_detail.present?
      return ph_remark if inv_grading_detail['Physical Condition'].blank?
      inv_grading_detail['Physical Condition'].each_with_index do |value, i|
        if i == 0
          ph_remark += "#{value['test']}: #{value['value']}"
        else
          ph_remark += " / #{value['test']}: #{value['value']}"
        end
      end
    end
    return ph_remark
  end


  def physical_remark_old
    remark = ''
    grading_detail = inventory_grading_details.last.details['final_grading_result'] rescue []
    if grading_detail.present?
      grading_detail.each do |k, value|
        substring = ''
        value.each_with_index do |updated, i|
          if k == 'Physical'
            substring += "#{grading_detail['Item Condition'][0]['annotations'][i]['orientation']} - " if (grading_detail['Item Condition'][0]['annotations'][i]['orientation'].present? rescue false)
            substring += "#{grading_detail['Item Condition'][0]['annotations'][i]['direction']}: " if (grading_detail['Item Condition'][0]['annotations'][i]['direction'].present? rescue false)
            substring += "#{updated['output']}, "
          end
        end
        remark += "#{substring} \n " if k == 'Physical'
      end
    end
    return remark
  end

  def self.update_disposition
    Inventory.where(disposition: 'Markdown').each do |i|
      i.disposition = "Pending Transfer Out"
      i.save(:validate => false)
    end
  end

  def self.generate_bulk_tag(count = 1, tag_sequence = 'bb')
    uniq_tags = []
    until uniq_tags.size == count
      size = count - uniq_tags.size
      tag_numbers = generate_tag_numbers(size, tag_sequence)
      present_tags = Inventory.where(tag_number: tag_numbers).pluck(:tag_number)
      uniq_tags += tag_numbers - present_tags
    end
    uniq_tags
  end

  def self.generate_tag_numbers(count, tag_sequence)
    tag_numbers = []
    count.times.map { tag_numbers << "#{tag_sequence}-#{SecureRandom.hex(3)}".downcase }
    tag_numbers.uniq
  end

  def self.generate_tag(is_standalone = false)
    loop do
      @tag_sequence = is_standalone ? 'bb' : 'T'
      @random_token = "#{@tag_sequence}-#{SecureRandom.hex(3)}".downcase
      break @random_token unless self.exists?(tag_number: @random_token)
    end
    return @random_token
  end

  def self.create_existing_record(row, gate_pass, gate_pass_inventory)
    client_category =  gate_pass_inventory.client_category
    user = gate_pass.user
    details_hash = Hash.new 
    client_category_hash = Hash.new
    grading_hash = Hash.new

    client_category.ancestors.each_with_index {|k, i| client_category_hash["category_l#{i+1}"] = k.name}
    client_category_hash["category_l#{client_category.ancestors.size+1}"] = client_category.name

    disposition = row["RPA pending Status"]

    details_hash = {"stn_number" => gate_pass_inventory.gate_pass.client_gatepass_number,
                    "dispatch_date" => gate_pass_inventory.gate_pass.dispatch_date.strftime("%Y-%m-%d %R"),
                    "inward_grading_time" => Time.now.to_s,
                    "inward_user_id" => user.id,
                    "inward_user_name" => user.username,
                    "source_code" => gate_pass_inventory.gate_pass.source_code,
                    "destination_code" => gate_pass_inventory.gate_pass.destination_code,
                    "inwarding_disposition" => disposition,
                    "brand" => gate_pass_inventory.brand,
                    "client_sku_master_id" => gate_pass_inventory.client_sku_master_id.try(:to_s),
                    "ean" => gate_pass_inventory.ean,
                    "merchandise_category" => gate_pass_inventory.merchandise_category,
                    "merch_cat_desc" => gate_pass_inventory.merch_cat_desc,
                    "site_name" => gate_pass_inventory.site_name,
                    "sto_date" => gate_pass_inventory.sto_date,
                    "group" => gate_pass_inventory.group,
                    "group_code" => gate_pass_inventory.group_code,
                    "grn_number" => row['GRN Number'],
                    "grn_date" => row['GRN Date'],
                    "grn_received_user_name" => user.username,
                    "grn_submitted_user_name" => user.username,
                    "grn_submitted_user_id" => user.id,
                    "grn_received_user_id" => user.id,
                    "grn_received_time" => row['GRN Date'].to_date,
                    "invoice_number" => row['Customer Invoice Number'],
                    "own_label" => (gate_pass_inventory.details.present? ? gate_pass_inventory.details["own_label"] : nil) }

    details_hash["RPA pending Status"] = row["RPA pending Status"] if row["RPA pending Status"].present?
    details_hash["work_flow_name"] = row["work_flow_name"] if row["work_flow_name"].present?

    if row["In-Policy/Out Policy for Liquidation Items"].present?
      policy = LookupValue.where(original_code: row["In-Policy/Out Policy for Liquidation Items"]).first
      details_hash["policy_id"] = policy.id
      details_hash["policy_type"] = policy.original_code
    end

    tag = self.generate_tag

    final_details_hash = details_hash.deep_merge!(client_category_hash)
    
    inventory_status_warehouse_pending_grn = LookupValue.where("code = ?", Rails.application.credentials.inventory_status_warehouse_pending_grn).first

    inventory = Inventory.new(user_id: user.id, gate_pass_id: gate_pass_inventory.gate_pass_id, distribution_center_id: gate_pass_inventory.distribution_center_id,
                              client_id: gate_pass_inventory.client_id, sku_code: gate_pass_inventory.sku_code, item_description: gate_pass_inventory.item_description, 
                              quantity: 1, gate_pass_inventory_id: gate_pass_inventory.id ,item_price: gate_pass_inventory.map, tag_number: tag,
                              client_tag_number: row["Tag Number"], disposition: disposition,
                              grade: row["Grade"], return_reason: row['Return Reason for RPA Inward'], details: final_details_hash,
                              serial_number: (row["Serial Number"].present? ? row["Serial Number"] : nil),
                              sr_number: (row["Sr Number"].present? ? row["Sr Number"] : nil), status: inventory_status_warehouse_pending_grn.original_code,
                              status_id: inventory_status_warehouse_pending_grn.try(:id), client_category_id: client_category.id, is_putaway_inwarded: false)

    inventory.inventory_statuses.build(status_id: inventory_status_warehouse_pending_grn.id, user_id: user.id, distribution_center_id: inventory.distribution_center_id,
                                       details: {"user_id" => user.id, "user_name" => user.username})

    not_tested_grade = LookupValue.where(code: Rails.application.credentials.inventory_grade_not_tested).last
    grade_id = not_tested_grade.id
    inventory.grade = not_tested_grade.original_code

    inventory.inventory_grading_details.build(distribution_center_id: inventory.distribution_center_id, user_id: inventory.user_id, details: {}, grade_id: grade_id)
    if inventory.save
      DispositionRule.create_bucket_record(inventory.disposition, inventory, "Inward", user.id)
    end
  end

  def self.billing_data_reverse
    
    @inventories = Inventory.includes(:inventory_statuses, :gate_pass_inventory, :vendor_return, :replacement, :insurance, :repair, :redeploy, :liquidation, :markdown, :e_waste, :pending_disposition).where("is_forward = ? and created_at >= ? and created_at <= ? and details ->> 'old_inventory_id' is null and (details ->> 'issue_type' != ? or details ->> 'issue_type' is null)", false, (1.month.ago.beginning_of_month), (1.month.ago.end_of_month), Rails.application.credentials.issue_type_in_transit)
 
    CSV.open("#{Rails.root}/public/#{(Time.now - 1.month).strftime("%B").downcase}_#{(Time.now - 1.month).strftime("%Y").downcase}_reverse_inventories.csv", "wb") do |csv|
      csv << ["RPA Site Code", "Store Site Code", "Inward Scan ID", "Brand Type", "Item Code", "Item Description", "Brand", "Serial Number", "Quantity", "MAP", "GRN Submitted Date", "GRN Received Date", "RPA pending Status", "Closure Date", "Created At", "Category L1", "Category L2", "Category L3", "EAN", "Grade"]
      @inventories.each do |i|
        rpa_pending_status = ""
        closure_date = ""
        if i.status == "Pending Brand Call-Log"
          rpa_pending_status = i.try(:vendor_return).try(:status)
        elsif i.status == "Pending Disposition"
          rpa_pending_status = i.try(:pending_disposition).try(:status)
        elsif i.status == "Pending Repair"
          rpa_pending_status = i.try(:repair).try(:status)
        elsif i.status == "Pending GRN"
          rpa_pending_status = i.try(:status)
        elsif i.status == "Pending Liquidation"
          rpa_pending_status = i.try(:liquidation).try(:status)
        elsif i.status == "Pending Insurance"
          rpa_pending_status = i.try(:insurance).try(:status)
        elsif i.status == "Pending E-Waste"
          rpa_pending_status = i.try(:e_waste).try(:status)
        elsif i.status == "Pending RTV"
          rpa_pending_status = i.try(:vendor_return).try(:status)
        elsif i.status == "Pending Replacement"
          rpa_pending_status = i.try(:replacement).try(:status)
        elsif i.status == "Pending Redeploy"
          rpa_pending_status = i.try(:redeploy).try(:status)
        elsif i.status == "Pending Issue Resolution"
          rpa_pending_status = i.try(:status)
        elsif i.status == "Closed Successfully"
          rpa_pending_status = i.try(:status)
          closure_date = (i.inventory_statuses.try(:last).try(:created_at).try(:to_time).strftime("%d-%m-%Y") rescue nil)
        else
          rpa_pending_status = i.try(:status)
        end
        csv << [i.details['destination_code'], i.details['source_code'], i.tag_number, (i.try(:gate_pass_inventory).try(:details)['own_label'] == true ? "OL" : "Non OL"), i.sku_code, i.item_description, i.details['brand'], i.serial_number, "1", i.item_price, (i.details["grn_submitted_date"].try(:to_time).strftime("%d-%m-%Y") rescue nil), (i.details["grn_received_time"].try(:to_time).strftime("%d-%m-%Y") rescue nil), rpa_pending_status, closure_date, i.created_at.try(:to_time).strftime("%d-%m-%Y"), i.details['category_l1'], i.details['category_l2'], i.details['category_l3'], i.details['ean'], i.try(:grade)] if i.details.present? && i.try(:gate_pass_inventory).present?
      end
    end
  end

  def self.billing_data_forward
    @gate_passes = GatePass.includes(:gate_pass_inventories, inventories: [:gate_pass_inventory]).where("is_forward = ? and document_submitted_time >= ? and document_submitted_time <= ? and status in (?)", true, (1.month.ago.beginning_of_month) - 5.5.hours, (1.month.ago.end_of_month) - 5.5.hours, ["Closed", "Completed"])
    CSV.open("#{Rails.root}/public/#{(Time.now - 1.month).strftime("%B").downcase}_#{(Time.now - 1.month).strftime("%Y").downcase}_forward_inventories.csv", "wb") do |csv|
      csv << ["Supplying Vendor / Site", "Receiving Site", "Document Date", "Document Number", "IDoc Number", "IDoc Created At", "Document Type", "Pickslip Number", "Item Number", "Article", "Article Description", "Category Code", "EAN", "Scan Ind", "Inwarded Quantity", "Serial Number", "IMEI1", "IMEI2", "Created At"]
      @gate_passes.each do |gate_pass|
        gate_pass.inventories.each do |inventory|
          if inventory.short_quantity.to_i == 0
            csv << [(gate_pass.document_type == "IBD" ? gate_pass.try(:vendor_code) : gate_pass.try(:source_code)), gate_pass.try(:destination_code), (gate_pass.dispatch_date.strftime("%d/%m/%Y") rescue nil), 
                    gate_pass.client_gatepass_number, gate_pass.idoc_number, (gate_pass.idoc_created_at.strftime("%d/%m/%Y") rescue nil), gate_pass.document_type, inventory.try(:gate_pass_inventory).try(:pickslip_number), inventory.details["item_number"],
                    inventory.try(:sku_code), inventory.try(:item_description), inventory.details["category_code_l3"], inventory.details["ean"], inventory.try(:details)["scan_id"],
                    inventory.try(:quantity), inventory.try(:serial_number), inventory.try(:imei1), inventory.try(:imei2), inventory.created_at.strftime("%d/%m/%Y")]
          end
        end
      end
    end
  end

  def self.push_obd_gr
    gate_pass_status_completed = LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_completed).first
    gate_pass_status_received = LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_received).first
    gate_passes = GatePass.includes(:inventories, :gate_pass_inventories).where("gate_passes.status = ? and gate_passes.document_type = ? and gate_passes.is_forward = ?", gate_pass_status_received.original_code, "OBD", true).references(:inventories, :gate_pass_inventories).limit(Rails.application.credentials.gr_documents_size)
    if gate_passes.present?
      json_params = self.create_inbound_json_payload("OBD-GR", gate_passes)
      if json_params[:payload].present?  
        push_inbound = PushInbound.create(batch_number: json_params[:batch_number], payload: json_params.to_json, master_data_type: "OBD-GR", status: "Pushed")
        headers = {"IntegrationType" => "OBD-GR", "app-id" => "BluBirch","Content-Type" => "application/json","target" => "sap","Authorization" => "Basic","Ocp-Apim-Subscription-Key" => Rails.application.credentials.sap_subscription_key }
        response = RestClient::Request.execute(:method => :post, :url => Rails.application.credentials.inbound_gr_apim_end_point, :payload => json_params.to_json, :timeout => 9000000, :headers => headers)
        gate_passes.each do |gate_pass|
          if gate_pass.gate_pass_inventories.collect(&:quantity).try(:sum) == (gate_pass.inventories.collect(&:quantity).collect(&:to_i).flatten.try(:sum) + gate_pass.inventories.collect(&:short_quantity).collect(&:to_i).flatten.try(:sum))
            gate_pass.update(status: gate_pass_status_completed.original_code, status_id: gate_pass_status_completed.id)
            gate_pass.inventories.update_all(is_pushed: true, pushed_at: Time.now, is_synced: true, synced_at: Time.now)
          end
        end
      end
    end
  end

  def self.push_ibd_gr
    gate_pass_status_completed = LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_completed).first
    gate_pass_status_received = LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_received).first
    gate_passes = GatePass.includes(:inventories, :gate_pass_inventories).where("gate_passes.status = ? and gate_passes.document_type = ? and gate_passes.is_forward = ?", gate_pass_status_received.original_code, "IBD", true).references(:inventories, :gate_pass_inventories).limit(Rails.application.credentials.gr_documents_size)
    if gate_passes.present?
      json_params = self.create_inbound_json_payload("IBD-GR", gate_passes)
      if json_params[:payload].present?
        push_inbound = PushInbound.create(batch_number: json_params[:batch_number], payload: json_params.to_json, master_data_type: "IBD-GR", status: "Pushed")
        headers = {"IntegrationType" => "IBD-GR", "app-id" => "BluBirch","Content-Type" => "application/json","target" => "sap","Authorization" => "Basic","Ocp-Apim-Subscription-Key" => Rails.application.credentials.sap_subscription_key }
        response = RestClient::Request.execute(:method => :post, :url => Rails.application.credentials.inbound_gr_apim_end_point, :payload => json_params.to_json, :timeout => 9000000, :headers => headers)
        gate_passes.each do |gate_pass|
          if gate_pass.gate_pass_inventories.collect(&:quantity).try(:sum) == (gate_pass.inventories.collect(&:quantity).collect(&:to_i).flatten.try(:sum) + gate_pass.inventories.collect(&:short_quantity).collect(&:to_i).flatten.try(:sum))
            gate_pass.update(status: gate_pass_status_completed.original_code, status_id: gate_pass_status_completed.id)
            gate_pass.inventories.update_all(is_pushed: true, pushed_at: Time.now, is_synced: true, synced_at: Time.now)
          end
        end
      end
    end
  end

  def self.push_gi_gr
    gate_pass_status_completed = LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_completed).first
    gate_pass_status_received = LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_received).first
    gate_passes = GatePass.includes(:inventories, :gate_pass_inventories).where("gate_passes.status = ? and gate_passes.document_type = ? and gate_passes.is_forward = ?", gate_pass_status_received.original_code, "GI", true).references(:inventories, :gate_pass_inventories).limit(Rails.application.credentials.gr_documents_size)
    if gate_passes.present?
      json_params = self.create_inbound_json_payload("GI-GR", gate_passes)
      if json_params[:payload].present?
        push_inbound = PushInbound.create(batch_number: json_params[:batch_number], payload: json_params.to_json, master_data_type: "GI-GR", status: "Pushed")
        headers = {"IntegrationType" => "GI-GR", "app-id" => "BluBirch","Content-Type" => "application/json","target" => "sap","Authorization" => "Basic","Ocp-Apim-Subscription-Key" => Rails.application.credentials.sap_subscription_key }
        response = RestClient::Request.execute(:method => :post, :url => Rails.application.credentials.inbound_gr_apim_end_point, :payload => json_params.to_json, :timeout => 9000000, :headers => headers)
        gate_passes.each do |gate_pass|
          if gate_pass.gate_pass_inventories.collect(&:quantity).try(:sum) == (gate_pass.inventories.collect(&:quantity).collect(&:to_i).flatten.try(:sum) + gate_pass.inventories.collect(&:short_quantity).collect(&:to_i).flatten.try(:sum))
            gate_pass.update(status: gate_pass_status_completed.original_code, status_id: gate_pass_status_completed.id)
            gate_pass.inventories.update_all(is_pushed: true, pushed_at: Time.now, is_synced: true, synced_at: Time.now)
          end
        end  
      end    
    end
  end

  def self.create_inbound_json_payload(document_type, gate_passes)
    batch_number = document_type.gsub("-", "") + "_" + "#{Time.now.strftime('%Y%m%d%H%M%S%L')}"
    json_payload = {"batch_number": batch_number}
    json_payload[:payload] = []
    gate_passes.each do |gate_pass|
      if gate_pass.gate_pass_inventories.collect(&:quantity).try(:sum) == (gate_pass.inventories.collect(&:quantity).collect(&:to_i).flatten.try(:sum) + gate_pass.inventories.collect(&:short_quantity).collect(&:to_i).flatten.try(:sum))
        document_details = []
        inventories = gate_pass.inventories.where("inventories.is_pushed = ?", false)
        non_serialized_and_short_quantity_items = inventories.where("short_quantity > 0 or details ->> 'scan_id' = ?", "N")
        inventories.each do |inventory|
          if inventory.try(:gate_pass_inventory).try(:pickslip_number).present? && inventory.try(:gate_pass_inventory).try(:pickslip_number) != "NOPICKSLIP"
            pickslip_number = inventory.try(:gate_pass_inventory).try(:pickslip_number)
          elsif inventory.try(:gate_pass_inventory).try(:pickslip_number).blank? || inventory.try(:gate_pass_inventory).try(:pickslip_number) == "NOPICKSLIP"
            pickslip_number = "null"
          else
            pickslip_number = "null"
          end
          document_details << {
                                "PickSlipNo": pickslip_number,
                                "ItemNumber": inventory.try(:details)["item_number"],
                                "Article": inventory.sku_code,
                                "ArticleDesc": inventory.item_description,
                                "Category": inventory.details["category_code_l3"],
                                "ExpectedQty": inventory.try(:gate_pass_inventory).try(:quantity).try(:to_s), 
                                "EAN": inventory.details["ean"],
                                "SerialNumber1": (inventory.serial_number.present? ? inventory.serial_number : (((inventory.short_quantity.to_i > 0) || (inventory.try(:gate_pass_inventory).try(:scan_id) == "N")) ? "Dummy-#{gate_pass.client_gatepass_number}_#{non_serialized_and_short_quantity_items.find_index(inventory)+1}" : "null")),
                                "IMEI1": (inventory.imei1.present? ? inventory.imei1 : "null"),
                                "IMEI2": (inventory.imei2.present? ? inventory.imei2 : "null"),
                                "ScanQuantity": inventory.quantity.to_s,
                                "ScanInd": ((inventory.short_quantity.to_i > 0) ? "N" : inventory.try(:gate_pass_inventory).try(:scan_id)),
                                "ReceivingSite": gate_pass.try(:destination_code),
                                "SupplyingSite": (document_type == "IBD-GR" ? gate_pass.try(:vendor_code) : gate_pass.try(:source_code)),
                                "ShortQty": (inventory.short_quantity.present? ? inventory.short_quantity.to_s : ""),
                                "ReasonforShort": (inventory.short_reason.present? ? inventory.short_reason : "")
                              }
        end
        json_payload[:payload] <<  {
                                      "DocumentType": document_type,
                                      "Document": gate_pass.client_gatepass_number,
                                      "ReceiptDate": gate_pass.created_at.strftime("%d.%m.%Y"),
                                      "DocumentDetails": document_details
                                    }
        gate_pass.update(gr_batch_number: batch_number)
      end
    end
    return json_payload
  end

  def self.push_pckslp_gi
    gate_pass_status_completed = LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_completed).first
    gate_pass_status_received = LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_received).first
    outbound_documents = OutboundDocument.includes(:outbound_inventories, :outbound_document_articles).where("outbound_documents.status = ? and outbound_documents.document_type = ? and outbound_documents.is_forward = ?", gate_pass_status_received.original_code, "PCKSLP", true).references(:outbound_inventories, :outbound_document_articles).limit(Rails.application.credentials.gr_documents_size)
    if outbound_documents.present?
      json_params = self.create_outbound_json_payload("PCKSLP-GI", outbound_documents)
      if json_params[:payload].present?
        push_inbound = PushInbound.create(batch_number: json_params[:batch_number], payload: json_params.to_json, master_data_type: "PCKSLP-GI", status: "Pushed")
        headers = {"IntegrationType" => "INBDPROGI", "app-id" => "BluBirch","Content-Type" => "application/json","target" => "sap","Authorization" => "Basic","Ocp-Apim-Subscription-Key" => Rails.application.credentials.sap_subscription_key }
        response = RestClient::Request.execute(:method => :post, :url => Rails.application.credentials.outbound_gi_apim_end_point, :payload => json_params.to_json, :timeout => 9000000, :headers => headers)
        outbound_documents.each do |outbound_document|
          if outbound_document.outbound_document_articles.collect(&:quantity).try(:sum) == (outbound_document.outbound_inventories.collect(&:quantity).collect(&:to_i).flatten.try(:sum) + outbound_document.outbound_inventories.collect(&:short_quantity).collect(&:to_i).flatten.try(:sum))
            outbound_document.update(status: gate_pass_status_completed.original_code, status_id: gate_pass_status_completed.id)
            outbound_document.outbound_inventories.update_all(is_pushed: true, pushed_at: Time.now, is_synced: true, synced_at: Time.now)
          end
        end  
      end    
    end
  end

  def self.push_rtn_gi
    gate_pass_status_completed = LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_completed).first
    gate_pass_status_received = LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_received).first
    outbound_documents = OutboundDocument.includes(:outbound_inventories, :outbound_document_articles).where("outbound_documents.status = ? and outbound_documents.document_type = ? and outbound_documents.is_forward = ?", gate_pass_status_received.original_code, "ZRTN", true).references(:outbound_inventories, :outbound_document_articles).limit(Rails.application.credentials.gr_documents_size)
    if outbound_documents.present?
      json_params = self.create_rtn_json_payload("RTN-GI", outbound_documents)
      if json_params[:payload].present?
        push_inbound = PushInbound.create(batch_number: json_params[:batch_number], payload: json_params.to_json, master_data_type: "RTN-GI", status: "Pushed")
        headers = {"IntegrationType" => "INBDPROGI", "app-id" => "BluBirch","Content-Type" => "application/json","target" => "sap","Authorization" => "Basic","Ocp-Apim-Subscription-Key" => Rails.application.credentials.sap_subscription_key }
        response = RestClient::Request.execute(:method => :post, :url => Rails.application.credentials.outbound_gi_apim_end_point, :payload => json_params.to_json, :timeout => 9000000, :headers => headers)
        outbound_documents.each do |outbound_document|
          if outbound_document.outbound_document_articles.collect(&:quantity).try(:sum) == (outbound_document.outbound_inventories.collect(&:quantity).collect(&:to_i).flatten.try(:sum) + outbound_document.outbound_inventories.collect(&:short_quantity).collect(&:to_i).flatten.try(:sum))
            outbound_document.update(status: gate_pass_status_completed.original_code, status_id: gate_pass_status_completed.id)
            outbound_document.outbound_inventories.update_all(is_pushed: true, pushed_at: Time.now, is_synced: true, synced_at: Time.now)
          end
        end  
      end    
    end
  end

  def self.create_outbound_json_payload(document_type, outbound_documents)
    batch_number = document_type.gsub("-", "") + "_" + "#{Time.now.strftime('%Y%m%d%H%M%S%L')}"
    json_payload = {"batch_number": batch_number}
    json_payload[:payload] = []
    outbound_documents.each do |outbound_document|
      if outbound_document.outbound_document_articles.collect(&:quantity).try(:sum) == (outbound_document.outbound_inventories.collect(&:quantity).collect(&:to_i).flatten.try(:sum) + outbound_document.outbound_inventories.collect(&:short_quantity).collect(&:to_i).flatten.try(:sum))
        document_details = []
        outbound_inventories = outbound_document.outbound_inventories.where("outbound_inventories.is_pushed = ?", false)
        non_serialized_and_short_quantity_items = outbound_inventories.where("short_quantity > 0 or details ->> 'scan_id' = ?", "N")
        outbound_inventories.each do |outbound_inventory|
          document_details << {
                                "ItemNumber": outbound_inventory.try(:details)["item_number"],
                                "Article": outbound_inventory.sku_code,
                                "ArticleDesc": outbound_inventory.item_description,
                                "Category": outbound_inventory.details["category_code_l3"],
                                "ExpectedQty": outbound_inventory.try(:outbound_document_article).try(:quantity).try(:to_s), 
                                "EAN": outbound_inventory.details["ean"],
                                "SerialNumber1": (outbound_inventory.serial_number.present? ? outbound_inventory.serial_number : (((outbound_inventory.short_quantity.to_i > 0) || (outbound_inventory.try(:outbound_document_article).try(:scan_id) == "N")) ? "Dummy-#{outbound_document.client_gatepass_number}_#{non_serialized_and_short_quantity_items.find_index(outbound_inventory)+1}" : "null")),
                                "IMEI1": (outbound_inventory.imei1.present? ? outbound_inventory.imei1 : "null"),
                                "IMEI2": (outbound_inventory.imei2.present? ? outbound_inventory.imei2 : "null"),
                                "ScanQuantity": outbound_inventory.quantity.to_s,
                                "ScanInd": ((outbound_inventory.short_quantity.to_i > 0) ? "N" : outbound_inventory.try(:outbound_document_article).try(:scan_id)),
                                "LocationID": (outbound_inventory.aisle_location.present? ? outbound_inventory.aisle_location : "null"),
                                "ReceivingSite": (document_type == "RTN-GI" ? outbound_document.try(:vendor_code) : outbound_document.try(:destination_code)),
                                "SupplyingSite": outbound_document.try(:source_code),
                                "ShortQty": (outbound_inventory.short_quantity.present? ? outbound_inventory.short_quantity.to_s : ""),
                                "ReasonforShort": (outbound_inventory.short_reason.present? ? outbound_inventory.short_reason : "")
                              }
        end
        json_payload[:payload] <<  {
                                      "DocumentType": document_type,
                                      "Document": outbound_document.client_gatepass_number,
                                      "ReceiptDate": outbound_document.created_at.strftime("%d.%m.%Y"),
                                      "DocumentDetails": document_details
                                    }
        outbound_document.update(gi_batch_number: batch_number)
      end
    end
    return json_payload
  end

  def self.create_rtn_json_payload(document_type, outbound_documents)
    batch_number = document_type.gsub("-", "") + "_" + "#{Time.now.strftime('%Y%m%d%H%M%S%L')}"
    json_payload = {"batch_number": batch_number}
    json_payload[:payload] = []
    outbound_documents.each do |outbound_document|
      if outbound_document.outbound_document_articles.collect(&:quantity).try(:sum) == (outbound_document.outbound_inventories.collect(&:quantity).collect(&:to_i).flatten.try(:sum) + outbound_document.outbound_inventories.collect(&:short_quantity).collect(&:to_i).flatten.try(:sum))
        document_details = []
        outbound_inventories = outbound_document.outbound_inventories.where("outbound_inventories.is_pushed = ?", false)
        non_serialized_and_short_quantity_items = outbound_inventories.where("short_quantity > 0 or details ->> 'scan_id' = ?", "N")
        outbound_inventories.each do |outbound_inventory|
          document_details << {
                                "ItemNumber": outbound_inventory.try(:details)["item_number"],
                                "Article": outbound_inventory.sku_code,
                                "ArticleDesc": outbound_inventory.item_description,
                                "Category": outbound_inventory.details["category_code_l3"],
                                "ExpectedQty": outbound_inventory.try(:outbound_document_article).try(:quantity).try(:to_s), 
                                "EAN": outbound_inventory.details["ean"],
                                "SerialNumber1": (outbound_inventory.serial_number.present? ? outbound_inventory.serial_number : (((outbound_inventory.short_quantity.to_i > 0) || (outbound_inventory.try(:outbound_document_article).try(:scan_id) == "N")) ? "Dummy-#{outbound_document.client_gatepass_number}_#{non_serialized_and_short_quantity_items.find_index(outbound_inventory)+1}" : "null")),
                                "IMEI1": (outbound_inventory.imei1.present? ? outbound_inventory.imei1 : "null"),
                                "IMEI2": (outbound_inventory.imei2.present? ? outbound_inventory.imei2 : "null"),
                                "ScanQuantity": outbound_inventory.quantity.to_s,
                                "ScanInd": ((outbound_inventory.short_quantity.to_i > 0) ? "N" : outbound_inventory.try(:outbound_document_article).try(:scan_id)),
                                "ReceivingSite": (document_type == "RTN-GI" ? outbound_document.try(:vendor_code) : outbound_document.try(:destination_code)),
                                "SupplyingSite": outbound_document.try(:source_code),
                                "ShortQty": (outbound_inventory.short_quantity.present? ? outbound_inventory.short_quantity.to_s : ""),
                                "ReasonforShort": (outbound_inventory.short_reason.present? ? outbound_inventory.short_reason : "")
                              }
        end
        json_payload[:payload] <<  {
                                      "DocumentType": document_type,
                                      "Document": outbound_document.client_gatepass_number,
                                      "ReceiptDate": outbound_document.created_at.strftime("%d.%m.%Y"),
                                      "DocumentDetails": document_details
                                    }
        outbound_document.update(gi_batch_number: batch_number)
      end
    end
    return json_payload
  end
  
  def get_suggested_sublocations(distribution_center)
    sub_locations = distribution_center.sub_locations
    suggested_ids = []
    sub_locations.each do |sub_location|
      if not sub_location.category.blank?
        next if not sub_location.category.include? self.details["category_l2"]
      end
      if not sub_location.brand.blank?
        next if not sub_location.brand.include? self.details["brand"]
      end
      if not sub_location.grade.blank?
        next if not sub_location.grade.include? self.grade
      end
      if not sub_location.disposition.blank?
        next if not sub_location.disposition.include? self.disposition
      end
      if not sub_location.return_reason.blank?
        next if not sub_location.return_reason.include? self.return_reason
      end
      suggested_ids << sub_location.id
    end
    
    suggested_sublocations = sub_locations.where(id: suggested_ids)
    suggested_sublocations
  end
  
  def update_inventory_status!(bucket_status, current_user_id = nil)
    existing_inventory_status = self.inventory_statuses.where(is_active: true).last
    inventory_status = existing_inventory_status.present? ? existing_inventory_status.dup : self.inventory_statuses.new
    inventory_status.status = bucket_status
    inventory_status.distribution_center_id = self.distribution_center_id
    inventory_status.is_active = true
    inventory_status.user_id = current_user_id
    existing_inventory_status.update(is_active: false) if existing_inventory_status.present?
    inventory_status.save!
    self.update(status: bucket_status.original_code, status_id: bucket_status.id)
  end

  def outward_inventory!(current_user)
    inventory_status_closed = LookupValue.where("code = ?", Rails.application.credentials.inventory_status_warehouse_closed_successfully).first
    
    active_inventory_status = self.inventory_statuses.where(is_active: true).last
    self.inventory_statuses.build(status_id: inventory_status_closed.id, user_id: current_user&.id, distribution_center_id: self.distribution_center_id, details: {"user_id" => current_user&.id, "user_name" => current_user&.username})
    self.assign_attributes({status_id: inventory_status_closed.id, status: inventory_status_closed.original_code})
    # self.details["dispatch_complete_date"] = Time.now.to_datetime
    if self.save
      current_bucket = get_current_bucket
      current_bucket.update!({status_id: inventory_status_closed.id, status: inventory_status_closed.original_code})
      active_inventory_status.update(is_active: false) if active_inventory_status.present?
    end
  end
  
  def put_request_created?
    pending_requests = self.put_requests.where(status: [1,2])
    pending_requests.present?
  end

  def get_bom_mappings
    ClientSkuMaster.find_by(code: self.sku_code).bom_mappings rescue nil
  end

  def self.validate_grade_mappings(where_qry)
    inv_grades = Inventory.joins(:liquidations).where(where_qry).select("inventories.grade, liquidations.sku_code")
    client_item_names = GradeMapping.where(client_item_name: inv_grades.pluck(:grade).uniq.compact).pluck(:client_item_name)
    inv_grades.map{|inv_grade| inv_grade.sku_code unless client_item_names.include?(inv_grade.grade) }.uniq.compact
  end
end
