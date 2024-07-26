class GatePass < ApplicationRecord
  acts_as_paranoid
  belongs_to :distribution_center
  belongs_to :user, optional: true
  belongs_to :client, optional: true
  belongs_to :master_data_input, optional: true
  belongs_to :assigned_user, optional: true, class_name: "User", foreign_key: :assigned_user_id
  belongs_to :gate_pass_status, class_name: "LookupValue", foreign_key: :status_id

  has_many :inventories
  has_many :gate_pass_inventories

  has_many :gate_pass_boxes
  has_many :packaging_boxes, through: :gate_pass_boxes

  has_one :consignment_gate_pass

  validates :client_gatepass_number, :document_type, :dispatch_date, :destination_code, presence: true
  validates :source_code, presence: true , if: -> {document_type != "IBD" }
  # validates :client_gatepass_number, uniqueness: true

  include Filterable
  include JsonUpdateable
  scope :filter_by_gatepass_number, -> (gatepass_number) { where("gatepass_number ilike ?", "%#{gatepass_number}%")}

  scope :opened, -> { where.not(status: "Closed Successfully") }

  def self.import(master_file_upload = nil, user = nil)
    errors_hash = Hash.new(nil)
    error_found = false
    begin
      master_file_upload = MasterFileUpload.where("id = ?", master_file_upload).first
      i = 0

      if master_file_upload.present?
        temp_file = open(master_file_upload.master_file.url)
        file = File.new(temp_file)
        data = CSV.read(file.path, {headers: true, encoding: "iso-8859-1:utf-8"})
        user = User.find(master_file_upload.user_id)
      else
        file = File.new("#{Rails.root}/public/sample_files/stn_documents.csv")
        data = CSV.read(file.path, {headers: true, encoding: "iso-8859-1:utf-8"})
        user = User.last
      end
    
      GatePass.transaction do
        data.each do |row|
          i += 1
          row_number = (i+1)
          move_to_next = false
          errors_hash.merge!(row_number => []) 
          gate_pass = GatePass.where(client_gatepass_number: row["STN No"]).first
          client_sku = ClientSkuMaster.where(code: row["SKU"]).first
          gatepass_inventory_pending_receipt_status =  LookupValue.where("code = ?", Rails.application.credentials.gatepass_inventory_status_pending_receipt).first
          gatepass_pending_receipt_status =  LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_pending_receipt).first
          client_category = client_sku.client_category if client_sku.present?
          source = DistributionCenter.where("code = ?" , row["Source Code"]).last
          destination = DistributionCenter.where("code = ?" , row["Destination Code"]).last
          client = Client.where(name: row["Client"]).first

          if row["STN No"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "STN Number is Mandatory for gate pass")
            errors_hash[row_number] << error_row
            move_to_next = true
          end
          if row["SKU"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "SKU is Mandatory for gate pass")
            errors_hash[row_number] << error_row
            move_to_next = true
          elsif client_sku.blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "SKU doesn't match")
            errors_hash[row_number] << error_row
            move_to_next = true
          end
          if row["Client"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Client is blank")
            errors_hash[row_number] << error_row
            move_to_next = true
          elsif client.blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Client is Mandatory")
            errors_hash[row_number] << error_row
            move_to_next = true
          end
          if row["Source Code"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Souce Code is blank")
            errors_hash[row_number] << error_row
            move_to_next = true
          elsif source.blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Source Code is not matching")
            errors_hash[row_number] << error_row
            move_to_next = true
          end
          if row["Destination Code"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Destination Code is blank")
            errors_hash[row_number] << error_row
            move_to_next = true
          elsif destination.blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Destination Code is not matching")
            errors_hash[row_number] << error_row
            move_to_next = true
          end
          if row["Quantity"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Quantity is empty")
            errors_hash[row_number] << error_row
            move_to_next = true
          end
          if row["Per Unit Price"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Unit Price is empty")
            errors_hash[row_number] << error_row
            move_to_next = true
          end
          if row["SKU Description"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "SKU Description is empty")
            errors_hash[row_number] << error_row
            move_to_next = true
          end
          

          next if move_to_next

          if gate_pass.present?
            inventories = gate_pass.gate_pass_inventories.where(sku_code: row["SKU"]).last
            if inventories.blank?
              gate_pass.gate_pass_inventories.create( distribution_center_id: destination.id, client_id: gate_pass.client_id, ean: client_sku.ean,
                                                      user_id: gate_pass.user_id, sku_code: row["SKU"], item_description: row["SKU Description"],
                                                      quantity: row["Quantity"], status: gatepass_inventory_pending_receipt_status.original_code, status_id: gatepass_inventory_pending_receipt_status.id, map: row["Per Unit Price"], client_category_id: client_category.id,
                                                      client_category_name: client_category.try(:name), brand: client_sku.brand, inwarded_quantity: 0, client_sku_master_id: client_sku.try(:id), details: {"own_label"=>client_sku.own_label} )
            end  
          else            
            gate_pass = GatePass.new( distribution_center_id: destination.id, client_id: Client.first.id,
                                      user_id: user.id, status_id: gatepass_pending_receipt_status.id, client_gatepass_number: row["STN No"], dispatch_date: row["Dispatch Date"].try(:to_datetime),
                                      sr_number: row["SR Number"], source_id: source.id, source_code: row["Source Code"], source_address: source.address, source_city: source.try(:city).try(:original_code), 
                                      source_state: source.try(:state).try(:original_code), source_country: source.try(:country).try(:original_code), destination_id: destination.id,
                                      destination_code: row["Destination Code"], destination_address: destination.address, destination_city: destination.try(:city).try(:original_code),
                                      destination_state: destination.try(:state).try(:original_code), destination_country: destination.try(:country).try(:original_code), 
                                      status: gatepass_pending_receipt_status.original_code, gatepass_number: "GP-#{SecureRandom.hex(3)}", total_quantity: row["Quantity"])
            if gate_pass.save
              gate_pass.gate_pass_inventories.create( distribution_center_id: destination.id, client_id: gate_pass.client_id, ean: client_sku.ean,
                                                      user_id: gate_pass.user_id, sku_code: row["SKU"], item_description: row["SKU Description"],
                                                      quantity: row["Quantity"], status: gatepass_inventory_pending_receipt_status.original_code, status_id: gatepass_inventory_pending_receipt_status.id, map: row["Per Unit Price"],
                                                      client_category_id: client_category.id, client_category_name: client_category.try(:name), brand: client_sku.brand, inwarded_quantity: 0,
                                                      client_sku_master_id: client_sku.try(:id), details: {"own_label"=>client_sku.own_label} )
            end
          end
          quantity = gate_pass.gate_pass_inventories.pluck(:quantity)
          gate_pass.update_attributes(total_quantity: quantity.sum)
        end
      end  
    ensure
      if error_found
        all_error_messages = errors_hash.values.flatten.collect do |h| h[:message].to_s end
        all_error_message_str = all_error_messages.join(',')
        master_file_upload.update(status: "Halted", remarks: all_error_message_str) if master_file_upload.present?
        return false
      else
        if (data.count == 0)
          master_file_upload.update(status: "Halted", remarks: "File is Empty")
          return false
        else  
          master_file_upload.update(status: "Completed") if master_file_upload.present?
          return true
        end
      end
    end
  end
  
  def self.prepare_error_hash(row, rownubmer, message)
    message = "Error In row number (#{rownubmer}) : " + message.to_s
    return {row: row, row_number: rownubmer, message: message}
  end

  def self.import_new(master_file_upload = nil, user = nil)
    errors_hash = Hash.new(nil)
    error_found = false
    eligible_retry_rows = []
    begin
      master_file_upload = MasterFileUpload.where("id = ?", master_file_upload).first
      i = 0

      if master_file_upload.present?
        temp_file = open(master_file_upload.master_file.url)
        file = File.new(temp_file)
        data = CSV.read(file.path, {headers: true, encoding: "iso-8859-1:utf-8"})
        user = User.find(master_file_upload.user_id)
      else
        file = File.new("#{Rails.root}/public/sample_files/transit_report.csv")
        data = CSV.read(file.path, {headers: true, encoding: "iso-8859-1:utf-8"})
        user = User.last
      end

      gate_pass_inv_arr = []
      obd_document_type = LookupValue.where("code = ?", Rails.application.credentials.obd_document_code).first
      gatepass_inventory_pending_receipt_status =  LookupValue.where("code = ?", Rails.application.credentials.gatepass_inventory_status_pending_receipt).first
      gatepass_pending_receipt_status =  LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_pending_receipt).first
      GatePass.transaction do
        data.each do |row|
          i += 1
          row_number = (i+1)
          move_to_next = false
          retry_row = false
          errors_hash.merge!(row_number => []) 
          gate_pass = GatePass.where("client_gatepass_number ilike (?)", "%#{row['Outbound Delivery']}%").last
          client_sku = ClientSkuMaster.where(code: row["Article"]).first          
          client_category = client_sku.client_category if client_sku.present?
          article_description = client_sku&.sku_description
          source = DistributionCenter.where("code = ?" , row["Supplying Site"]).last
          destination = DistributionCenter.where("code = ?" , row["Receiving Site"]).last
          client = Client.where(name: row["Client"]).first
          
          if row["Article"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "SKU is Mandatory for gate pass")
            errors_hash[row_number] << error_row
            move_to_next = true
            retry_row = false
          elsif client_sku.blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "SKU doesn't match")
            errors_hash[row_number] << error_row
            move_to_next = true
            retry_row = true
          end

          if row["Supplying Site"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Supplying Site is blank")
            errors_hash[row_number] << error_row
            move_to_next = true
            retry_row = false
          elsif source.blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Supplying Site is not matching")
            errors_hash[row_number] << error_row
            move_to_next = true
            retry_row = false
          end
          if row["Receiving Site"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Receiving Site is blank")
            errors_hash[row_number] << error_row
            move_to_next = true
            retry_row = false
          elsif destination.blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Receiving Site is not matching")
            errors_hash[row_number] << error_row
            move_to_next = true
            retry_row = false
          end
          if row["GI Qty"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "GI Qty is empty")
            errors_hash[row_number] << error_row
            move_to_next = true
            retry_row = false
          end
          if row["GI Cost"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "GI cost is empty")
            errors_hash[row_number] << error_row
            move_to_next = true
            retry_row = false
          end
          if row["Merchandise Category"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Merchandise Category is empty")
            errors_hash[row_number] << error_row
            move_to_next = true
            retry_row = false
          end
          if row["Merch Cat Desc"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Merch Cat Desc is empty")
            errors_hash[row_number] << error_row
            move_to_next = true
            retry_row = false
          end
          if row["STO No"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "STO No is empty")
            errors_hash[row_number] << error_row
            move_to_next = true
            retry_row = false
          end
          if row["Line Item"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Line Item is empty")
            errors_hash[row_number] << error_row
            move_to_next = true
            retry_row = false
          end
          if row["Document Type"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Document Type is empty")
            errors_hash[row_number] << error_row
            move_to_next = true
            retry_row = false
          end
          if row["Outbound Delivery"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Outbound Delivery is empty")
            errors_hash[row_number] << error_row
            move_to_next = true
            retry_row = false
          end
          if row["STO Date"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "STO Date is empty")
            errors_hash[row_number] << error_row
            move_to_next = true
            retry_row = false
          end
          if row["Group"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Group is empty")
            errors_hash[row_number] << error_row
            move_to_next = true
            retry_row = false
          end
          if row["Group Code"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Group Code is empty")
            errors_hash[row_number] << error_row
            move_to_next = true
            retry_row = false
          end
          eligible_retry_rows << row_number if retry_row
          next if move_to_next || (master_file_upload.retrying? && master_file_upload.retry_rows.exclude?(row_number))
          if gate_pass.present?
            inventories = gate_pass.gate_pass_inventories.where(sku_code: row["Article"]).last
            if inventories.blank? && (gate_pass_inv_arr.find {|x| x[:id] == gate_pass.id }.present? || master_file_upload.retrying?)
              gate_pass.gate_pass_inventories.create(distribution_center_id: destination.id, client_id: gate_pass.client_id, ean: client_sku.ean, user_id: gate_pass.user_id, sku_code: row["Article"], item_description: article_description, quantity: row["GI Qty"].to_i, status: gatepass_inventory_pending_receipt_status.original_code, status_id: gatepass_inventory_pending_receipt_status.id, map: row["GI Cost"], client_category_id: client_category.id,client_category_name: client_category.try(:name), brand: client_sku.brand, inwarded_quantity: 0, client_sku_master_id: client_sku.try(:id), details: {"own_label"=>client_sku.own_label} , merchandise_category: row["Merchandise Category"] , merch_cat_desc: row["Merch Cat Desc"],item_number: row["Line Item"], line_item: row["Line Item"] , document_type: row["Document Type"], site_name: row["Site Name"],consolidated_gi: row["Consolidated GI"], sto_date: row["STO Date"].try(:to_datetime) , group: row["Group"] , group_code: row["Group Code"], sku_eans: client_sku.sku_eans.collect(&:ean).flatten, scan_id: ((client_sku.scannable_flag == true) ? "Y" : "N"), pickslip_number: "NOPICKSLIP", map: row['GI Cost'])
              gate_pass_inv_arr << {id: gate_pass.id, sku_code: row["Article"]}
            elsif inventories.present? && (gate_pass_inv_arr.find {|x| (x[:id] == gate_pass.id) && (x[:sku_code] == row["Article"]) }.present? || master_file_upload.retrying?)
              inventories.update(quantity: (inventories.quantity + row["GI Qty"].to_i)) if row["GI Qty"].present?
            end  
          else
            gate_pass = GatePass.new( distribution_center_id: destination.id, client_id: Client.first.id, user_id: user.id, status_id: gatepass_pending_receipt_status.id, client_gatepass_number: row["Outbound Delivery"], dispatch_date: row["GI Date"].try(:to_datetime), sr_number: nil, source_id: source.id, source_code: row["Supplying Site"], source_address: source.address, source_city: source.try(:city).try(:original_code), source_state: source.try(:state).try(:original_code), source_country: source.try(:country).try(:original_code), destination_id: destination.id,destination_code: row["Receiving Site"], destination_address: destination.address, destination_city: destination.try(:city).try(:original_code), destination_state: destination.try(:state).try(:original_code), destination_country: destination.try(:country).try(:original_code), status: gatepass_pending_receipt_status.original_code, gatepass_number: "GP-#{SecureRandom.hex(3)}", total_quantity: row["GI Qty"], document_type: obd_document_type.try(:original_code), document_type_id: obd_document_type.try(:id), is_forward: false)
            gate_pass.gate_pass_inventories.build(distribution_center_id: destination.id, client_id: gate_pass.client_id, ean: client_sku.ean, user_id: gate_pass.user_id, sku_code: row["Article"], item_description: article_description, quantity: row["GI Qty"], status: gatepass_inventory_pending_receipt_status.original_code, status_id: gatepass_inventory_pending_receipt_status.id, map: row["GI Cost"],client_category_id: client_category.id, client_category_name: client_category.try(:name), brand: client_sku.brand, inwarded_quantity: 0, client_sku_master_id: client_sku.try(:id), details: {"own_label"=>client_sku.own_label} , merchandise_category: row["Merchandise Category"] , merch_cat_desc: row["Merch Cat Desc"],item_number: row["Line Item"], line_item: row["Line Item"] , document_type: row["Document Type"], site_name: row["Site Name"],consolidated_gi: row["Consolidated GI"], sto_date: row["STO Date"].try(:to_datetime) , group: row["Group"] , group_code: row["Group Code"], sku_eans: client_sku.sku_eans.collect(&:ean).flatten, scan_id: ((client_sku.scannable_flag == true) ? "Y" : "N"), pickslip_number: "NOPICKSLIP", map: row['GI Cost'])
            if gate_pass.save
              gate_pass_inv_arr << {id: gate_pass.id, sku_code: row["Article"]}
            end
          end 
          quantity = gate_pass.gate_pass_inventories.pluck(:quantity)
          gate_pass.update_attributes(total_quantity: quantity.sum)         
        end
      end  
    ensure
      if error_found
        all_error_messages = errors_hash.values.flatten.collect do |h| h[:message].to_s end
        all_error_message_str = all_error_messages.join(',')
        master_file_upload.update(status: "Halted", remarks: all_error_message_str, retry_rows: eligible_retry_rows) if master_file_upload.present?
        return false
      else
        if (data.count == 0)
          master_file_upload.update(status: "Halted", remarks: "File is Empty", retry_rows: eligible_retry_rows) if master_file_upload.present?
          return false
        else  
          master_file_upload.update(status: "Completed", retry_rows: eligible_retry_rows) if master_file_upload.present?
          return true
        end
      end
    end
  end

  def update_status
    inventories = self.inventories.reload
    gate_pass_inventories = self.gate_pass_inventories.reload

    if inventories.present?
      quantity_values = []
      inventories.each do |inventory|
        if inventory.details["rsto_number"].present? || inventory.details["grn_number"].present?
          quantity_values <<  "close"
        else
          quantity_values <<  "open"
        end

        gate_pass_inventories = gate_pass_inventories.where.not(id: inventory.gate_pass_inventory_id)
        if gate_pass_inventories.present?
          gate_pass_inventories.each do |gate_pass_inventory|
            if gate_pass_inventory.inwarded_quantity < gate_pass_inventory.quantity
              if gate_pass_inventory.inventories.blank?
                quantity_values <<  "open"
              end
            end
          end
        end
      end
      
      if quantity_values.include?("open")
        gatepass_sts =  LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_open).first
        self.update(status_id: gatepass_sts.id, status: gatepass_sts.original_code)
      else
        gatepass_sts =  LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_closed).first
        self.update(status_id: gatepass_sts.id, status: gatepass_sts.original_code)
      end
    end
  end

  def self.import_old_inventories_into_system(path)
    # Uploading Stn File
    errors_hash = Hash.new(nil)
    error_found = false
    #begin
      file = File.new(path)
      i = 0

      data = CSV.read(file.path, {headers: true, encoding: "iso-8859-1:utf-8"})
      user = User.last

      gate_pass_inv_arr = []
    
      GatePass.transaction do
        data.each do |row|
          i += 1
          row_number = (i+1)
          move_to_next = false
          errors_hash.merge!(row_number => []) 
          gate_pass = GatePass.where(client_gatepass_number: row["Outbound Delivery"], is_forward: false).first
          client_sku = ClientSkuMaster.where(code: row["Article"]).first
          gatepass_inventory_pending_receipt_status =  LookupValue.where("code = ?", Rails.application.credentials.gatepass_inventory_status_pending_receipt).first
          gatepass_pending_receipt_status =  LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_pending_receipt).first
          client_category = client_sku.client_category if client_sku.present?
          source = DistributionCenter.where("code = ?" , row["Supplying Site"]).last
          destination = DistributionCenter.where("code = ?" , row["Receiving Site"]).last
          client = Client.where(name: row["Client"]).first
          if row["Article"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "SKU is Mandatory for gate pass")
            errors_hash[row_number] << error_row
            move_to_next = true
          elsif client_sku.blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "SKU doesn't match")
            errors_hash[row_number] << error_row
            move_to_next = true
          end
          if row["Supplying Site"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Supplying Site is blank")
            errors_hash[row_number] << error_row
            move_to_next = true
          elsif source.blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Supplying Site is not matching")
            errors_hash[row_number] << error_row
            move_to_next = true
          end
          if row["Receiving Site"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Receiving Site is blank")
            errors_hash[row_number] << error_row
            move_to_next = true
          elsif destination.blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Receiving Site is not matching")
            errors_hash[row_number] << error_row
            move_to_next = true
          end
          if row["GI Qty"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "GI Qty is empty")
            errors_hash[row_number] << error_row
            move_to_next = true
          end
          # if row["GI Cost"].blank?
          #   error_found = true
          #   error_row = prepare_error_hash(row, row_number, "GI cost is empty")
          #   errors_hash[row_number] << error_row
          #   move_to_next = true
          # end
          if row["Merchandise Category"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Merchandise Category is empty")
            errors_hash[row_number] << error_row
            move_to_next = true
          end
          if row["Merch Cat Desc"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Merch Cat Desc is empty")
            errors_hash[row_number] << error_row
            move_to_next = true
          end
          if row["STO No"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "STO No is empty")
            errors_hash[row_number] << error_row
            move_to_next = true
          end
          if row["Line Item"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Line Item is empty")
            errors_hash[row_number] << error_row
            move_to_next = true
          end
          if row["Document Type"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Document Type is empty")
            errors_hash[row_number] << error_row
            move_to_next = true
          end
          if row["Outbound Delivery"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Outbound Delivery is empty")
            errors_hash[row_number] << error_row
            move_to_next = true
          end
          if row["STO Date"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "STO Date is empty")
            errors_hash[row_number] << error_row
            move_to_next = true
          end
          if row["Group"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Group is empty")
            errors_hash[row_number] << error_row
            move_to_next = true
          end
          if row["Group Code"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Group Code is empty")
            errors_hash[row_number] << error_row
            move_to_next = true
          end
          if row["Article Desc"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Article Desc is empty")
            errors_hash[row_number] << error_row
            move_to_next = true
          end

          next if move_to_next

          if gate_pass.present?
            inventories = gate_pass.gate_pass_inventories.where(sku_code: row["Article"]).last
            if inventories.blank? #&& gate_pass_inv_arr.find {|x| x[:id] == gate_pass.id }.present?              
              inventories = gate_pass.gate_pass_inventories.create(distribution_center_id: destination.id, client_id: gate_pass.client_id, ean: client_sku.ean, user_id: gate_pass.user_id, sku_code: row["Article"], item_description: row["Article Desc"], quantity: row["GI Qty"].to_i, status: gatepass_inventory_pending_receipt_status.original_code, status_id: gatepass_inventory_pending_receipt_status.id, map: row["GI Cost"], client_category_id: client_category.id,client_category_name: client_category.try(:name), brand: client_sku.brand, inwarded_quantity: 0, client_sku_master_id: client_sku.try(:id), details: {"own_label"=>client_sku.own_label} , merchandise_category: row["Merchandise Category"] , merch_cat_desc: row["Merch Cat Desc"],line_item: row["Line Item"] , document_type: row["Document Type"], site_name: row["Site Name"],consolidated_gi: row["Consolidated GI"], sto_date: row["STO Date"].try(:to_datetime) , group: row["Group"] , group_code: row["Group Code"])
              gate_pass_inv_arr << {id: gate_pass.id, sku_code: row["Article"]}
            elsif inventories.present? #&& gate_pass_inv_arr.find {|x| (x[:id] == gate_pass.id) && (x[:sku_code] == row["Article"]) }.present?
              inventories.update(quantity: (inventories.quantity + row["GI Qty"].to_i)) if row["GI Qty"].present?
            end

            Inventory.create_existing_record(row, gate_pass, inventories)
          else
            gate_pass = GatePass.new( distribution_center_id: destination.id, client_id: Client.first.id, user_id: user.id, status_id: gatepass_pending_receipt_status.id, client_gatepass_number: row["Outbound Delivery"], dispatch_date: row["GI Date"].try(:to_datetime), sr_number: nil, source_id: source.id, source_code: row["Supplying Site"], source_address: source.address, source_city: source.try(:city).try(:original_code), source_state: source.try(:state).try(:original_code), source_country: source.try(:country).try(:original_code), destination_id: destination.id,destination_code: row["Receiving Site"], destination_address: destination.address, destination_city: destination.try(:city).try(:original_code), destination_state: destination.try(:state).try(:original_code), destination_country: destination.try(:country).try(:original_code), status: gatepass_pending_receipt_status.original_code, gatepass_number: "GP-#{SecureRandom.hex(3)}", total_quantity: row["GI Qty"], document_type: 'OBD', is_forward: false)
            gate_pass_inventory = gate_pass.gate_pass_inventories.build(distribution_center_id: destination.id, client_id: gate_pass.client_id, ean: client_sku.ean, user_id: gate_pass.user_id, sku_code: row["Article"], item_description: row["Article Desc"], quantity: row["GI Qty"], status: gatepass_inventory_pending_receipt_status.original_code, status_id: gatepass_inventory_pending_receipt_status.id, map: row["GI Cost"],client_category_id: client_category.id, client_category_name: client_category.try(:name), brand: client_sku.brand, inwarded_quantity: 0, client_sku_master_id: client_sku.try(:id), details: {"own_label"=>client_sku.own_label} , merchandise_category: row["Merchandise Category"] , merch_cat_desc: row["Merch Cat Desc"],line_item: row["Line Item"] , document_type: row["Document Type"], site_name: row["Site Name"],consolidated_gi: row["Consolidated GI"], sto_date: row["STO Date"].try(:to_datetime) , group: row["Group"] , group_code: row["Group Code"], scan_id: (client_sku.scannable_flag ? 'Y' : 'N'), item_number: "000010")
            if gate_pass.save
              gate_pass_inventory.save
              gate_pass_inv_arr << {id: gate_pass.id, sku_code: row["Article"]}
            end
            Inventory.create_existing_record(row, gate_pass, gate_pass_inventory )
          end 
          quantity = gate_pass.gate_pass_inventories.pluck(:quantity)
          gate_pass.update_attributes(total_quantity: quantity.sum)
        end
      end
    #end
  end

  def self.create_master_data(master_data_id)
    master_data = MasterDataInput.where("id = ?", master_data_id).first    
    gatepass_pending_receipt_status =  LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_pending_receipt).first
    client = Client.first
    user = User.first
    if master_data.present?
      ibd_document_type = LookupValue.where("code = ?", Rails.application.credentials.ibd_document_code).first
      obd_document_type = LookupValue.where("code = ?", Rails.application.credentials.obd_document_code).first
      errors_hash = Hash.new(nil)
      errors_hash["batchnumber"] = master_data.payload["batch_number"]
      errors_hash["errortype"] = "INWARDS"
      errors_hash["messages"] = []
      error_messages = []
      error_found = false
      success_count = 0
      failed_count = 0
      begin
        # ActiveRecord::Base.transaction do
          master_data.payload["payload"].each do |gate_pass_params|          
            move_to_next = false
            if ibd_document_type.try(:original_code) == gate_pass_params["document_type"]

              destination = DistributionCenter.where("code = ?" , gate_pass_params["destination_code"]).last
              # errors_hash.merge!(gate_pass_params["client_gatepass_number"] => [])
              if gate_pass_params["destination_code"].blank?
                destination_error = "Destination Code is missing"
              elsif destination.nil?
                destination_error = "Destination Code is not found in Blubirch system"
              end
              if gate_pass_params["client_gatepass_number"].blank?
                document_number_error = "Document Number is missing"
              end
              if gate_pass_params["document_type"].blank?
                document_type_error = "Document Type is missing"
              end
              if gate_pass_params["vendor_code"].blank?
                source_code_error = "Vendor Code is missing"
              end
              next if move_to_next

                gate_pass = GatePass.includes(:gate_pass_inventories).where(document_type_id: ibd_document_type.id, client_gatepass_number: gate_pass_params["client_gatepass_number"]).first
                
                if gate_pass.nil? #if move_to_next ==  false && gate_pass.nil?
                  gate_pass = GatePass.new(document_type_id: ibd_document_type.id, document_type: ibd_document_type.original_code, 
                                           vendor_name: gate_pass_params["vendor_name"], client_gatepass_number: gate_pass_params["client_gatepass_number"],
                                           dispatch_date: gate_pass_params["dispatch_date"].try(:to_datetime), vendor_code: gate_pass_params["vendor_code"],
                                           client_id: client.try(:id), user_id: user.try(:id), status_id: gatepass_pending_receipt_status.id, 
                                           status: gatepass_pending_receipt_status.original_code, distribution_center_id: destination.try(:id), 
                                           destination_id: destination.try(:id), destination_code: gate_pass_params["destination_code"], destination_address: (destination.present? ? destination.try(:address) : nil), 
                                           destination_city: destination.try(:city).try(:original_code), destination_state: destination.try(:state).try(:original_code), 
                                           destination_country: destination.try(:country).try(:original_code), gatepass_number: "GP-#{SecureRandom.hex(3)}",
                                           batch_number: master_data.payload["batch_number"], idoc_number: gate_pass_params["idoc_number"], idoc_created_at: gate_pass_params["idoc_created_at"],
                                           master_data_input_id: master_data.id)

                  error_found , response_error_messages = self.create_items(gate_pass_params["item_list"], gate_pass, error_messages, destination, destination_error, document_number_error, document_type_error, source_code_error)              
                  errors_hash["messages"] << response_error_messages

                elsif move_to_next ==  false && gate_pass.present? && gate_pass.try(:status_id) == gatepass_pending_receipt_status.id

                  if gate_pass.update( document_type_id: ibd_document_type.id, document_type: ibd_document_type.original_code, 
                                       vendor_name: gate_pass_params["vendor_name"], client_gatepass_number: gate_pass_params["client_gatepass_number"],
                                       dispatch_date: gate_pass_params["dispatch_date"].try(:to_datetime), vendor_code: gate_pass_params["vendor_code"],
                                       client_id: client.try(:id), user_id: user.try(:id), status_id: gatepass_pending_receipt_status.id, 
                                       status: gatepass_pending_receipt_status.original_code, distribution_center_id: destination.try(:id), 
                                       destination_id: destination.try(:id), destination_code: gate_pass_params["destination_code"], destination_address: (destination.present? ? destination.try(:address) : nil), 
                                       destination_city: destination.try(:city).try(:original_code), destination_state: destination.try(:state).try(:original_code), 
                                       destination_country: destination.try(:country).try(:original_code), gatepass_number: "GP-#{SecureRandom.hex(3)}",
                                       batch_number: master_data.payload["batch_number"], idoc_number: gate_pass_params["idoc_number"], idoc_created_at: gate_pass_params["idoc_created_at"],
                                       master_data_input_id: master_data.id)

                    if gate_pass.gate_pass_inventories.present?
                      gate_pass.gate_pass_inventories.each do |gp|
                        gp.really_destroy!
                      end
                    end

                    error_found , response_error_messages = self.create_items(gate_pass_params["item_list"], gate_pass, error_messages, destination, destination_error, document_number_error, document_type_error, source_code_error)              
                    errors_hash["messages"] << response_error_messages
                  end

                end
                if error_found == false
                  success_count = success_count + 1
                else
                  failed_count = failed_count + 1
                end

            elsif obd_document_type.try(:original_code) == gate_pass_params["document_type"]

              source = DistributionCenter.where("code = ?" , gate_pass_params["source_code"]).last
              destination = DistributionCenter.where("code = ?" , gate_pass_params["destination_code"]).last
              # errors_hash.merge!(gate_pass_params["client_gatepass_number"] => [])
              if gate_pass_params["destination_code"].blank?
                destination_error = "Destination Code is missing"
              elsif destination.nil?
                destination_error = "Destination Code is not found in Blubirch system"
              end
              if gate_pass_params["source_code"].blank?
                source_error = "Source Code is missing"
              elsif source.nil?
                source_error = "Source Code is not found in Blubirch system"
              end
              if gate_pass_params["client_gatepass_number"].blank?
                document_number_error = "Document Number is missing"
              end
              if gate_pass_params["document_type"].blank?
                document_type_error = "Document Type is missing"
              end
                            
              next if move_to_next

                
                if ((destination.try(:site_category) == "R") || (destination.try(:site_category) == "B"))
                  
                  gate_pass = ReturnDocument.includes(:return_document_inventories).where(document_type_id: obd_document_type.id, client_gatepass_number: gate_pass_params["client_gatepass_number"]).first
                  if gate_pass.nil? #if move_to_next ==  false && gate_pass.nil?
                    gate_pass = ReturnDocument.new(document_type_id: obd_document_type.id, document_type: obd_document_type.original_code, 
                                             client_gatepass_number: gate_pass_params["client_gatepass_number"], dispatch_date: gate_pass_params["dispatch_date"].try(:to_datetime), 
                                             client_id: client.try(:id), user_id: user.try(:id), status_id: gatepass_pending_receipt_status.id, 
                                             status: gatepass_pending_receipt_status.original_code, distribution_center_id: destination.try(:id), destination_id: destination.try(:id),
                                             destination_code: gate_pass_params["destination_code"], destination_address: (destination.present? ? destination.try(:address) : nil),
                                             destination_city: destination.try(:city).try(:original_code), destination_state: destination.try(:state).try(:original_code), 
                                             destination_country: destination.try(:country).try(:original_code), gatepass_number: "GP-#{SecureRandom.hex(3)}",
                                             source_code: gate_pass_params["source_code"], source_id: source.try(:id),
                                             source_address: (source.present? ? source.try(:address) : nil), source_city: source.try(:city).try(:original_code), 
                                             source_state: source.try(:state).try(:original_code), 
                                             source_country: source.try(:country).try(:original_code), is_forward: (((destination.try(:site_category) == "R") || (destination.try(:site_category) == "B")) ? false : true),
                                             batch_number: master_data.payload["batch_number"], idoc_number: gate_pass_params["idoc_number"], idoc_created_at: gate_pass_params["idoc_created_at"],
                                             master_data_input_id: master_data.id)

                    error_found , response_error_messages = self.create_return_items(gate_pass_params["item_list"], gate_pass, error_messages, destination, destination_error, document_number_error, document_type_error, source_error)
                    errors_hash["messages"] << response_error_messages
                    
                  elsif gate_pass.present? && gate_pass.try(:status_id) == gatepass_pending_receipt_status.id

                    if gate_pass.update( document_type_id: obd_document_type.id, document_type: obd_document_type.original_code, 
                                         client_gatepass_number: gate_pass_params["client_gatepass_number"], dispatch_date: gate_pass_params["dispatch_date"].try(:to_datetime), 
                                         client_id: client.try(:id), user_id: user.try(:id), status_id: gatepass_pending_receipt_status.id, 
                                         status: gatepass_pending_receipt_status.original_code, distribution_center_id: destination.try(:id), destination_id: destination.try(:id),
                                         destination_code: gate_pass_params["destination_code"], destination_address: (destination.present? ? destination.try(:address) : nil),
                                         destination_city: destination.try(:city).try(:original_code), destination_state: destination.try(:state).try(:original_code), 
                                         destination_country: destination.try(:country).try(:original_code), gatepass_number: "GP-#{SecureRandom.hex(3)}",
                                         source_code: gate_pass_params["source_code"], source_id: source.try(:id),
                                         source_address: (source.present? ? source.try(:address) : nil), source_city: source.try(:city).try(:original_code), 
                                         source_state: source.try(:state).try(:original_code), 
                                         source_country: source.try(:country).try(:original_code), is_forward: (((destination.try(:site_category) == "R") || (destination.try(:site_category) == "B")) ? false : true),
                                         batch_number: master_data.payload["batch_number"], idoc_number: gate_pass_params["idoc_number"], idoc_created_at: gate_pass_params["idoc_created_at"],
                                         master_data_input_id: master_data.id)

                      gate_pass.return_document_inventories.destroy_all

                      error_found , response_error_messages = self.create_return_items(gate_pass_params["item_list"], gate_pass, error_messages, destination, destination_error, document_number_error, document_type_error, source_error)
                      errors_hash["messages"] << response_error_messages
                    end

                  end

                else #if ((destination.try(:site_category) == "R") || (destination.try(:site_category) == "B"))
                  
                  gate_pass = GatePass.includes(:gate_pass_inventories).where(document_type_id: obd_document_type.id, client_gatepass_number: gate_pass_params["client_gatepass_number"]).first
                  if gate_pass.nil? #if move_to_next ==  false && gate_pass.nil?
                    gate_pass = GatePass.new(document_type_id: obd_document_type.id, document_type: obd_document_type.original_code, 
                                             client_gatepass_number: gate_pass_params["client_gatepass_number"], dispatch_date: gate_pass_params["dispatch_date"].try(:to_datetime), 
                                             client_id: client.try(:id), user_id: user.try(:id), status_id: gatepass_pending_receipt_status.id, 
                                             status: gatepass_pending_receipt_status.original_code, distribution_center_id: destination.try(:id), destination_id: destination.try(:id),
                                             destination_code: gate_pass_params["destination_code"], destination_address: (destination.present? ? destination.try(:address) : nil),
                                             destination_city: destination.try(:city).try(:original_code), destination_state: destination.try(:state).try(:original_code), 
                                             destination_country: destination.try(:country).try(:original_code), gatepass_number: "GP-#{SecureRandom.hex(3)}",
                                             source_code: gate_pass_params["source_code"], source_id: source.try(:id),
                                             source_address: (source.present? ? source.try(:address) : nil), source_city: source.try(:city).try(:original_code), 
                                             source_state: source.try(:state).try(:original_code), 
                                             source_country: source.try(:country).try(:original_code), is_forward: (((destination.try(:site_category) == "R") || (destination.try(:site_category) == "B")) ? false : true),
                                             batch_number: master_data.payload["batch_number"], idoc_number: gate_pass_params["idoc_number"], idoc_created_at: gate_pass_params["idoc_created_at"],
                                             master_data_input_id: master_data.id)

                    error_found , response_error_messages = self.create_items(gate_pass_params["item_list"], gate_pass, error_messages, destination, destination_error, document_number_error, document_type_error, source_error)
                    errors_hash["messages"] << response_error_messages
                    
                  elsif gate_pass.present? && gate_pass.try(:status_id) == gatepass_pending_receipt_status.id

                    if gate_pass.update( document_type_id: obd_document_type.id, document_type: obd_document_type.original_code, 
                                         client_gatepass_number: gate_pass_params["client_gatepass_number"], dispatch_date: gate_pass_params["dispatch_date"].try(:to_datetime), 
                                         client_id: client.try(:id), user_id: user.try(:id), status_id: gatepass_pending_receipt_status.id, 
                                         status: gatepass_pending_receipt_status.original_code, distribution_center_id: destination.try(:id), destination_id: destination.try(:id),
                                         destination_code: gate_pass_params["destination_code"], destination_address: (destination.present? ? destination.try(:address) : nil),
                                         destination_city: destination.try(:city).try(:original_code), destination_state: destination.try(:state).try(:original_code), 
                                         destination_country: destination.try(:country).try(:original_code), gatepass_number: "GP-#{SecureRandom.hex(3)}",
                                         source_code: gate_pass_params["source_code"], source_id: source.try(:id),
                                         source_address: (source.present? ? source.try(:address) : nil), source_city: source.try(:city).try(:original_code), 
                                         source_state: source.try(:state).try(:original_code), 
                                         source_country: source.try(:country).try(:original_code), is_forward: (((destination.try(:site_category) == "R") || (destination.try(:site_category) == "B")) ? false : true),
                                         batch_number: master_data.payload["batch_number"], idoc_number: gate_pass_params["idoc_number"], idoc_created_at: gate_pass_params["idoc_created_at"],
                                         master_data_input_id: master_data.id)

                      if gate_pass.gate_pass_inventories.present?
                        gate_pass.gate_pass_inventories.each do |gp|
                          gp.really_destroy!
                        end
                      end

                      error_found , response_error_messages = self.create_items(gate_pass_params["item_list"], gate_pass, error_messages, destination, destination_error, document_number_error, document_type_error, source_error)
                      errors_hash["messages"] << response_error_messages
                    end

                  end

                end #if ((destination.try(:site_category) == "R") || (destination.try(:site_category) == "B"))
                if error_found == false
                  success_count = success_count + 1
                else
                  failed_count = failed_count + 1
                end

            end # if ibd_document_type.try(:original_code) == gate_pass_params[:document_type]
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
        end 
        # Push Response to SAP Via APIM Ends by calling CRON Server

        # headers = {"IntegrationType" => "INBDERROR", "Ocp-Apim-Subscription-Key" => Rails.application.credentials.sap_subscription_key }
        # response = RestClient::Request.execute(:method => :post, :url => Rails.application.credentials.inbound_sap_error_apim_end_point, :payload => errors_hash.to_json, :timeout => 9000000, :headers => headers)
      end  # begin end
    end # if master_data.present?
  end # Method End


  def self.create_gi_master_data(master_data_id)
    master_data = MasterDataInput.where("id = ?", master_data_id).first    
    gatepass_pending_receipt_status =  LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_pending_receipt).first
    client = Client.first
    user = User.first
    if master_data.present?
      gi_document_type = LookupValue.where("code = ?", Rails.application.credentials.gi_document_code).first
      errors_hash = Hash.new(nil)
      errors_hash["batchnumber"] = master_data.payload["batch_number"]
      errors_hash["errortype"] = "INWARDS"
      errors_hash["messages"] = []
      error_messages = []
      error_found = false
      success_count = 0
      failed_count = 0
      begin
        # ActiveRecord::Base.transaction do
          master_data.payload["payload"].each do |gate_pass_params|
            destination = DistributionCenter.where("code = ?" , gate_pass_params["destination_code"]).last
            source = DistributionCenter.where("code = ?" , gate_pass_params["source_code"]).last
            move_to_next = false
            if gi_document_type.try(:original_code) == gate_pass_params["document_type"]
              # errors_hash.merge!(gate_pass_params["client_gatepass_number"] => [])
              if gate_pass_params["destination_code"].blank?
                destination_error = "Destination Code is missing"
              elsif destination.nil?
                destination_error = "Destination Code is not found in Blubirch system"
              end
              if gate_pass_params["source_code"].blank?
                source_error = "Source Code is missing"
              elsif source.nil?
                source_error = "Source Code is not found in Blubirch system"
              end
              if gate_pass_params["client_gatepass_number"].blank?
                document_number_error = "Document Number is missing"
              end
              if gate_pass_params["document_type"].blank?
                document_type_error = "Document Type is missing"
              end
              
              next if move_to_next

                if ((destination.try(:site_category) == "R") || (destination.try(:site_category) == "B"))

                  gate_pass = ReturnDocument.includes(:return_document_inventories).where(document_type_id: gi_document_type.id, client_gatepass_number: gate_pass_params["client_gatepass_number"]).first
                  
                  if gate_pass.nil? #if move_to_next ==  false && gate_pass.nil?
                    gate_pass = ReturnDocument.new(document_type_id: gi_document_type.id, document_type: gi_document_type.original_code, 
                                             client_gatepass_number: gate_pass_params["client_gatepass_number"], dispatch_date: gate_pass_params["dispatch_date"].try(:to_datetime),
                                             client_id: client.try(:id), user_id: user.try(:id), status_id: gatepass_pending_receipt_status.id, 
                                             status: gatepass_pending_receipt_status.original_code, distribution_center_id: destination.try(:id), 
                                             destination_id: destination.try(:id), destination_code: gate_pass_params["destination_code"], destination_address: (destination.present? ? destination.try(:address) : nil),
                                             destination_city: destination.try(:city).try(:original_code), destination_state: destination.try(:state).try(:original_code), 
                                             destination_country: destination.try(:country).try(:original_code), gatepass_number: "GP-#{SecureRandom.hex(3)}",
                                             source_code: gate_pass_params["source_code"], source_id: source.try(:id),
                                             source_address: (source.present? ? source.try(:address) : nil), source_city: source.try(:city).try(:original_code), 
                                             source_state: source.try(:state).try(:original_code), source_country: source.try(:country).try(:original_code), 
                                             is_forward: (((destination.try(:site_category) == "R") || (destination.try(:site_category) == "B")) ? false : true), batch_number: master_data.payload["batch_number"],
                                             master_data_input_id: master_data.id)

                    error_found , response_error_messages = self.create_return_gi_items(gate_pass_params["pickslip_details"], gate_pass, error_messages, destination, destination_error, document_number_error, document_type_error, source_error)              
                    errors_hash["messages"] << response_error_messages
                  elsif gate_pass.present? && gate_pass.try(:status_id) == gatepass_pending_receipt_status.id

                    gate_pass.update( document_type_id: gi_document_type.id, document_type: gi_document_type.original_code, 
                                      client_gatepass_number: gate_pass_params["client_gatepass_number"], client_id: client.try(:id), user_id: user.try(:id), status_id: gatepass_pending_receipt_status.id, 
                                      status: gatepass_pending_receipt_status.original_code, distribution_center_id: destination.try(:id), 
                                      destination_id: destination.try(:id), destination_code: gate_pass_params["destination_code"], destination_address: (destination.present? ? destination.try(:address) : nil),
                                      destination_city: destination.try(:city).try(:original_code), destination_state: destination.try(:state).try(:original_code), 
                                      destination_country: destination.try(:country).try(:original_code), gatepass_number: "GP-#{SecureRandom.hex(3)}",
                                      source_code: gate_pass_params["source_code"], source_id: source.try(:id),
                                      source_address: (source.present? ? source.try(:address) : nil), source_city: source.try(:city).try(:original_code), 
                                      source_state: source.try(:state).try(:original_code), source_country: source.try(:country).try(:original_code), 
                                      is_forward: (((destination.try(:site_category) == "R") || (destination.try(:site_category) == "B")) ? false : true), batch_number: master_data.payload["batch_number"],
                                      master_data_input_id: master_data.id)

                    error_found , response_error_messages = self.create_return_gi_items(gate_pass_params["pickslip_details"], gate_pass, error_messages, destination, destination_error, document_number_error, document_type_error, source_error)              
                    errors_hash["messages"] << response_error_messages

                  end
                  
                else # if ((destination.try(:site_category) == "R") || (destination.try(:site_category) == "B"))

                  gate_pass = GatePass.includes(:gate_pass_inventories).where(document_type_id: gi_document_type.id, client_gatepass_number: gate_pass_params["client_gatepass_number"]).first
                  
                  if gate_pass.nil? #if move_to_next ==  false && gate_pass.nil?
                    gate_pass = GatePass.new(document_type_id: gi_document_type.id, document_type: gi_document_type.original_code, 
                                             vendor_name: gate_pass_params["vendor_name"], client_gatepass_number: gate_pass_params["client_gatepass_number"],
                                             dispatch_date: gate_pass_params["dispatch_date"].try(:to_datetime), vendor_code: gate_pass_params["vendor_code"],
                                             client_id: client.try(:id), user_id: user.try(:id), status_id: gatepass_pending_receipt_status.id, 
                                             status: gatepass_pending_receipt_status.original_code, distribution_center_id: destination.try(:id), 
                                             destination_id: destination.try(:id), destination_code: gate_pass_params["destination_code"], destination_address: (destination.present? ? destination.try(:address) : nil),
                                             destination_city: destination.try(:city).try(:original_code), destination_state: destination.try(:state).try(:original_code), 
                                             destination_country: destination.try(:country).try(:original_code), gatepass_number: "GP-#{SecureRandom.hex(3)}",
                                             source_code: gate_pass_params["source_code"], source_id: source.try(:id),
                                             source_address: (source.present? ? source.try(:address) : nil), source_city: source.try(:city).try(:original_code), 
                                             source_state: source.try(:state).try(:original_code), source_country: source.try(:country).try(:original_code), 
                                             is_forward: (((destination.try(:site_category) == "R") || (destination.try(:site_category) == "B")) ? false : true), batch_number: master_data.payload["batch_number"],
                                             master_data_input_id: master_data.id)

                    error_found , response_error_messages = self.create_gi_items(gate_pass_params["pickslip_details"], gate_pass, error_messages, destination, destination_error, document_number_error, document_type_error, source_error)              
                    errors_hash["messages"] << response_error_messages
                  elsif gate_pass.present? && gate_pass.try(:status_id) == gatepass_pending_receipt_status.id

                    gate_pass.update( document_type_id: gi_document_type.id, document_type: gi_document_type.original_code, 
                                      vendor_name: gate_pass_params["vendor_name"], client_gatepass_number: gate_pass_params["client_gatepass_number"],
                                      dispatch_date: gate_pass_params["dispatch_date"].try(:to_datetime), vendor_code: gate_pass_params["vendor_code"],
                                      client_id: client.try(:id), user_id: user.try(:id), status_id: gatepass_pending_receipt_status.id, 
                                      status: gatepass_pending_receipt_status.original_code, distribution_center_id: destination.try(:id), 
                                      destination_id: destination.try(:id), destination_code: gate_pass_params["destination_code"], destination_address: (destination.present? ? destination.try(:address) : nil),
                                      destination_city: destination.try(:city).try(:original_code), destination_state: destination.try(:state).try(:original_code), 
                                      destination_country: destination.try(:country).try(:original_code), gatepass_number: "GP-#{SecureRandom.hex(3)}",
                                      source_code: gate_pass_params["source_code"], source_id: source.try(:id),
                                      source_address: (source.present? ? source.try(:address) : nil), source_city: source.try(:city).try(:original_code), 
                                      source_state: source.try(:state).try(:original_code), source_country: source.try(:country).try(:original_code), 
                                      is_forward: (((destination.try(:site_category) == "R") || (destination.try(:site_category) == "B")) ? false : true), batch_number: master_data.payload["batch_number"],
                                      master_data_input_id: master_data.id)

                    error_found , response_error_messages = self.create_gi_items(gate_pass_params["pickslip_details"], gate_pass, error_messages, destination, destination_error, document_number_error, document_type_error, source_error)              
                    errors_hash["messages"] << response_error_messages

                  end

                end  # if ((destination.try(:site_category) == "R") || (destination.try(:site_category) == "B"))
                if error_found == false
                  success_count = success_count + 1
                else
                  failed_count = failed_count + 1
                end
            end # if gi_document_type.try(:original_code) == gate_pass_params[:document_type]
          end # master_data.payload
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
        end 
        # Push Response to SAP Via APIM Ends by calling CRON Server


        # headers = {"IntegrationType" => "INBDERROR", "Ocp-Apim-Subscription-Key" => Rails.application.credentials.sap_subscription_key  }
        # response = RestClient::Request.execute(:method => :post, :url => Rails.application.credentials.inbound_sap_error_apim_end_point, :payload => errors_hash.to_json, :timeout => 9000000, :headers => headers)
      end # begin end
    end # if master_data.present?
  end # Method End

  def self.create_items(items_array, gate_pass, error_messages, destination, destination_error = nil, document_number_error = nil, document_type_error = nil, source_error = nil)
    gatepass_inventory_pending_receipt_status =  LookupValue.where("code = ?", Rails.application.credentials.gatepass_inventory_status_pending_receipt).first
    success_item_count = 0
    failure_item_count = 0
    failure_items = []
    success_items = []

    success_item_error = {"successmsg": "null"}     
    items_array.each do |gate_pass_item_params|
      scan_id = gate_pass_item_params["scan_id"]
      serial_number_length = 0
      error = false
      error_code = []
      client_sku_master = ClientSkuMaster.includes(:client_category, :sku_eans).where("code = ?", gate_pass_item_params["sku_code"]).last
      exceptional_article = ExceptionalArticle.where("sku_code ilike (?)", "%#{gate_pass_item_params['sku_code'].sub(/^[0]+/,'')}%").last
      exceptional_article_serial_number = ExceptionalArticleSerialNumber.where("sku_code ilike (?)", "%#{gate_pass_item_params['sku_code'].sub(/^[0]+/,'')}%").last
      if exceptional_article.present?
        scan_id = ((exceptional_article.scan_id.present?) ? exceptional_article.scan_id : gate_pass_item_params["scan_id"])
      else
        scan_id = gate_pass_item_params["scan_id"]
      end
      if exceptional_article_serial_number.present?
        serial_number_length = ((exceptional_article_serial_number.serial_number_length > 0) ? exceptional_article_serial_number.serial_number_length : 0)
      else
        serial_number_length = 0
      end
      if gate_pass_item_params["sku_code"].blank?
        error = true
        error_code << "01"
      end
      if client_sku_master.nil?
        error = true
        error_code << "02"        
      end
      if gate_pass_item_params["quantity"].blank?
        error = true
        error_code << "03"        
      end
      if gate_pass_item_params["scan_id"].blank?
        error = true
        error_code << "04"        
      end
      if gate_pass_item_params["category_code"].blank?
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
      if source_error.present? && ((source_error == "Source Code is missing") || (source_error == "Vendor Code is missing"))
        error = true
        error_code << "10"        
      elsif source_error.present? && source_error == "Source Code is not found in Blubirch system"
        error = true
        error_code << "11"
      end
      if gate_pass_item_params["item_number"].blank?
        error = true
        error_code << "12"
      end
      if error == false
        gate_pass.gate_pass_inventories.build(sku_code: gate_pass_item_params["sku_code"], scan_id: scan_id,
                                              quantity: gate_pass_item_params["quantity"], item_description: (gate_pass_item_params["sku_description"].present? ? gate_pass_item_params["sku_description"] : client_sku_master.sku_description), 
                                              merchandise_category: (gate_pass_item_params["category_code"].present? ? gate_pass_item_params["category_code"] : client_sku_master.description["category_code_l3"]), merch_cat_desc: gate_pass_item_params["sku_description"],
                                              line_item: (gate_pass_item_params["category_code"].present? ? gate_pass_item_params["category_code"] : client_sku_master.description["category_code_l3"]),
                                              client_category_id: client_sku_master.client_category_id, brand: client_sku_master.brand, 
                                              client_category_name: client_sku_master.client_category.name, client_sku_master_id: client_sku_master.id,
                                              item_number: gate_pass_item_params["item_number"], inwarded_quantity: 0, status: gatepass_inventory_pending_receipt_status.original_code, 
                                              status_id: gatepass_inventory_pending_receipt_status.id, distribution_center_id: destination.id, 
                                              client_id: gate_pass.client_id, user_id: gate_pass.user_id, details: {"own_label"=> client_sku_master.own_label },
                                              sku_eans: client_sku_master.sku_eans.collect(&:ean).flatten, imei_flag: (client_sku_master.try(:imei_flag).present? ? client_sku_master.try(:imei_flag) : "0"),
                                              serial_number_length: serial_number_length, pickslip_number: "NOPICKSLIP")
        success_item_count = success_item_count + 1
        # failure_items << { "itemnumber": gate_pass_item_params["item_number"].to_s, "errormsg": "null" }
      else
        failure_item_count = failure_item_count + 1

        concat_error_messages = "null"
        if error_code.present?
          error_string = []
          error_string << "Article" if (error_code.include?("01"))
          error_string << "Quantity" if (error_code.include?("03")) 
          error_string << "ScanInd" if (error_code.include?("04"))
          error_string << "CategoryCode" if (error_code.include?("05"))
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

        failure_items << { "itemnumber": gate_pass_item_params["item_number"].to_s, "errormsg": concat_error_messages }
      end      
    end

    

    if ((failure_item_count == 0) && gate_pass.valid?)
      if gate_pass.save
        if (success_item_error[:successmsg] == "null")
          success_item_error[:successmsg] = "DocumentNumber #{gate_pass.client_gatepass_number} is posted successfully."
        end
        success_items << success_item_error 
        failure_items << { "itemnumber": "null", "errormsg": "null" }
        document_hash = {"documentnumber": gate_pass.client_gatepass_number, "numberofitem": items_array.size.to_s, "successitemcount": success_item_count.to_s, "failureitemcount": failure_item_count.to_s, "failureitems": failure_items.flatten, "success": success_items.flatten}
        error_messages = document_hash
        return false, error_messages       
      else
        success_items << success_item_error
        success_item_count = 0
        document_hash = {"documentnumber": gate_pass.client_gatepass_number, "numberofitem": items_array.size.to_s, "successitemcount": success_item_count.to_s, "failureitemcount": failure_item_count.to_s, "failureitems": failure_items.flatten, "success": success_items.flatten}
        error_messages = document_hash
        return true, error_messages
      end
    elsif failure_item_count != 0
      success_items << success_item_error
      success_item_count = 0
      # failure_items.flat_map { |failure_item| failure_item[:errormsg] = "Not processed due to Master data issue in document" if failure_item[:errormsg] == "null" }
      document_hash = {"documentnumber": gate_pass.client_gatepass_number, "numberofitem": items_array.size.to_s, "successitemcount": success_item_count.to_s, "failureitemcount": failure_item_count.to_s, "failureitems": failure_items.flatten, "success": success_items.flatten}
      error_messages = document_hash
      return true, error_messages
    end
  end

  def self.create_gi_items(pickslip_details, gate_pass, errors_hash, destination, destination_error = nil, document_number_error = nil, document_type_error = nil, source_error = nil)
    gatepass_inventory_pending_receipt_status =  LookupValue.where("code = ?", Rails.application.credentials.gatepass_inventory_status_pending_receipt).first
    success_item_count = 0
    failure_item_count = 0
    failure_items = []
    success_items = []
    items_count = 0

    success_item_error = {"successmsg": "null"}
    pickslip_details.each do |pickslip_detail|
      items_count = items_count + pickslip_detail['item_list'].size
      pickslip_detail['item_list'].each do |gate_pass_item_params|
        scan_id = gate_pass_item_params["scan_id"]
        serial_number_length = 0
        error = false
        error_code = []
        client_sku_master = ClientSkuMaster.includes(:client_category, :sku_eans).where("code = ?", gate_pass_item_params["sku_code"]).last
        exceptional_article = ExceptionalArticle.where("sku_code ilike (?)", "%#{gate_pass_item_params['sku_code'].sub(/^[0]+/,'')}%").last
        exceptional_article_serial_number = ExceptionalArticleSerialNumber.where("sku_code ilike (?)", "%#{gate_pass_item_params['sku_code'].sub(/^[0]+/,'')}%").last
        if exceptional_article.present?
          scan_id = ((exceptional_article.scan_id.present?) ? exceptional_article.scan_id : gate_pass_item_params["scan_id"])
        else
          scan_id = gate_pass_item_params["scan_id"]
        end
        if exceptional_article_serial_number.present?
          serial_number_length = ((exceptional_article_serial_number.serial_number_length > 0) ? exceptional_article_serial_number.serial_number_length : 0)
        else
          serial_number_length = 0
        end
        if gate_pass_item_params["sku_code"].blank?
          error = true
          error_code << "01"
        end
        if client_sku_master.nil?
          error = true
          error_code << "02"        
        end
        if gate_pass_item_params["quantity"].blank?
          error = true
          error_code << "03"        
        end
        if gate_pass_item_params["scan_id"].blank?
          error = true
          error_code << "04"        
        end
        if gate_pass_item_params["sku_category"].blank?
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
        if source_error.present? && ((source_error == "Source Code is missing") || (source_error == "Vendor Code is missing"))
          error = true
          error_code << "10"        
        elsif source_error.present? && source_error == "Source Code is not found in Blubirch system"
          error = true
          error_code << "11"
        end
        if gate_pass_item_params["item_number"].blank?
          error = true
          error_code << "12"
        end
        if error == false
          gate_pass_inventory = gate_pass.gate_pass_inventories.where(sku_code: gate_pass_item_params["sku_code"], pickslip_number: pickslip_detail["pickslip_number"], item_number: gate_pass_item_params["item_number"]).last
          if gate_pass_inventory.present?
            gate_pass_inventory.update( sku_code: gate_pass_item_params["sku_code"], scan_id: scan_id,
                                        quantity: gate_pass_item_params["quantity"], item_description: (gate_pass_item_params["sku_description"].present? ? gate_pass_item_params["sku_description"] : client_sku_master.sku_description), 
                                        merchandise_category: (gate_pass_item_params["category_code"].present? ? gate_pass_item_params["category_code"] : client_sku_master.description["category_code_l3"]), merch_cat_desc: gate_pass_item_params["sku_description"],
                                        line_item: (gate_pass_item_params["category_code"].present? ? gate_pass_item_params["category_code"] : client_sku_master.description["category_code_l3"]),
                                        client_category_id: client_sku_master.client_category_id, brand: client_sku_master.brand, 
                                        client_category_name: client_sku_master.client_category.name, client_sku_master_id: client_sku_master.id,
                                        item_number: gate_pass_item_params["item_number"], inwarded_quantity: 0, status: gatepass_inventory_pending_receipt_status.original_code, 
                                        status_id: gatepass_inventory_pending_receipt_status.id, distribution_center_id: destination.id, 
                                        client_id: gate_pass.client_id, user_id: gate_pass.user_id, details: {"own_label"=> client_sku_master.own_label},
                                        pickslip_number: pickslip_detail["pickslip_number"], sku_eans: client_sku_master.sku_eans.collect(&:ean).flatten, imei_flag: (client_sku_master.try(:imei_flag).present? ? client_sku_master.try(:imei_flag) : "0"),
                                        serial_number_length: serial_number_length)
          else
            gate_pass.gate_pass_inventories.build(sku_code: gate_pass_item_params["sku_code"], scan_id: scan_id,
                                                  quantity: gate_pass_item_params["quantity"], item_description: (gate_pass_item_params["sku_description"].present? ? gate_pass_item_params["sku_description"] : client_sku_master.sku_description), 
                                                  merchandise_category: (gate_pass_item_params["category_code"].present? ? gate_pass_item_params["category_code"] : client_sku_master.description["category_code_l3"]), merch_cat_desc: gate_pass_item_params["sku_description"],
                                                  line_item: (gate_pass_item_params["category_code"].present? ? gate_pass_item_params["category_code"] : client_sku_master.description["category_code_l3"]),
                                                  client_category_id: client_sku_master.client_category_id, brand: client_sku_master.brand, 
                                                  client_category_name: client_sku_master.client_category.name, client_sku_master_id: client_sku_master.id,
                                                  item_number: gate_pass_item_params["item_number"], inwarded_quantity: 0, status: gatepass_inventory_pending_receipt_status.original_code, 
                                                  status_id: gatepass_inventory_pending_receipt_status.id, distribution_center_id: destination.id, 
                                                  client_id: gate_pass.client_id, user_id: gate_pass.user_id, details: {"own_label"=> client_sku_master.own_label},
                                                  pickslip_number: pickslip_detail["pickslip_number"], sku_eans: client_sku_master.sku_eans.collect(&:ean).flatten, imei_flag: (client_sku_master.try(:imei_flag).present? ? client_sku_master.try(:imei_flag) : "0"),
                                                  serial_number_length: serial_number_length)
          end
          success_item_count = success_item_count + 1
          # failure_items << { "itemnumber": gate_pass_item_params["item_number"].to_s, "errormsg": "null" }
        else
          failure_item_count = failure_item_count + 1
          
          concat_error_messages = "null"
          if error_code.present?
            error_string = []
            error_string << "Article" if (error_code.include?("01"))
            error_string << "Quantity" if (error_code.include?("03")) 
            error_string << "ScanInd" if (error_code.include?("04"))
            error_string << "CategoryCode" if (error_code.include?("05"))
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

          failure_items << { "itemnumber": gate_pass_item_params["item_number"].to_s, "errormsg": concat_error_messages }
        end
      end   
    end
    if ((failure_item_count == 0) && gate_pass.valid?)
      if gate_pass.save
        if (success_item_error[:successmsg] == "null")
          success_item_error[:successmsg] = "DocumentNumber #{gate_pass.client_gatepass_number} is posted successfully."
        end
        success_items << success_item_error
        failure_items << { "itemnumber": "null", "errormsg": "null" }
        document_hash = {"documentnumber": gate_pass.client_gatepass_number, "numberofitem": items_count.to_s, "successitemcount": success_item_count.to_s, "failureitemcount": failure_item_count.to_s, "failureitems": failure_items.flatten, "success": success_items.flatten }
        error_messages = document_hash
        return false, error_messages       
      else
        success_items << success_item_error
        success_item_count = 0
        document_hash = {"documentnumber": gate_pass.client_gatepass_number, "numberofitem": items_count.to_s, "successitemcount": success_item_count.to_s, "failureitemcount": failure_item_count.to_s, "failureitems": failure_items.flatten, "success": success_items.flatten }
        error_messages = document_hash
        return true, error_messages
      end
    elsif failure_item_count != 0
      success_items << success_item_error
      success_item_count = 0
      # failure_items.flat_map { |failure_item| failure_item[:errormsg] = "Not processed due to Master data issue in document" if failure_item[:errormsg] == "null" }
      document_hash = {"documentnumber": gate_pass.client_gatepass_number, "numberofitem": items_count.to_s, "successitemcount": success_item_count.to_s, "failureitemcount": failure_item_count.to_s, "failureitems": failure_items.flatten, "success": success_items.flatten }
      error_messages = document_hash
      return true, error_messages
    end
  end

  def self.create_return_items(items_array, gate_pass, error_messages, destination, destination_error = nil, document_number_error = nil, document_type_error = nil, source_error = nil)
    gatepass_inventory_pending_receipt_status =  LookupValue.where("code = ?", Rails.application.credentials.gatepass_inventory_status_pending_receipt).first
    success_item_count = 0
    failure_item_count = 0
    failure_items = []
    success_items = []

    success_item_error = {"successmsg": "null"}     
    items_array.each do |gate_pass_item_params|
      error = false
      error_code = []
      client_sku_master = ClientSkuMaster.includes(:client_category, :sku_eans).where("code = ?", gate_pass_item_params["sku_code"]).last
      if gate_pass_item_params["sku_code"].blank?
        error = true
        error_code << "01"
      end
      if client_sku_master.nil?
        error = true
        error_code << "02"        
      end
      if gate_pass_item_params["quantity"].blank?
        error = true
        error_code << "03"        
      end
      if gate_pass_item_params["scan_id"].blank?
        error = true
        error_code << "04"        
      end
      if gate_pass_item_params["category_code"].blank?
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
      if source_error.present? && ((source_error == "Source Code is missing") || (source_error == "Vendor Code is missing"))
        error = true
        error_code << "10"        
      elsif source_error.present? && source_error == "Source Code is not found in Blubirch system"
        error = true
        error_code << "11"
      end
      if gate_pass_item_params["item_number"].blank?
        error = true
        error_code << "12"
      end
      if error == false
        gate_pass.return_document_inventories.build(sku_code: gate_pass_item_params["sku_code"], scan_id: gate_pass_item_params["scan_id"],
                                              quantity: gate_pass_item_params["quantity"], item_description: (gate_pass_item_params["sku_description"].present? ? gate_pass_item_params["sku_description"] : client_sku_master.sku_description), 
                                              merchandise_category: (gate_pass_item_params["category_code"].present? ? gate_pass_item_params["category_code"] : client_sku_master.description["category_code_l3"]), merch_cat_desc: gate_pass_item_params["sku_description"],
                                              line_item: (gate_pass_item_params["category_code"].present? ? gate_pass_item_params["category_code"] : client_sku_master.description["category_code_l3"]),
                                              client_category_id: client_sku_master.client_category_id, brand: client_sku_master.brand, 
                                              client_category_name: client_sku_master.client_category.name, client_sku_master_id: client_sku_master.id,
                                              item_number: gate_pass_item_params["item_number"], inwarded_quantity: 0, status: gatepass_inventory_pending_receipt_status.original_code, 
                                              status_id: gatepass_inventory_pending_receipt_status.id, distribution_center_id: destination.id, 
                                              client_id: gate_pass.client_id, user_id: gate_pass.user_id, details: {"own_label"=> client_sku_master.own_label },
                                              sku_eans: client_sku_master.sku_eans.collect(&:ean).flatten, imei_flag: (client_sku_master.try(:imei_flag).present? ? client_sku_master.try(:imei_flag) : "0"))
        success_item_count = success_item_count + 1
        # failure_items << { "itemnumber": gate_pass_item_params["item_number"].to_s, "errormsg": "null" }
      else
        failure_item_count = failure_item_count + 1

        concat_error_messages = "null"
        if error_code.present?
          error_string = []
          error_string << "Article" if (error_code.include?("01"))
          error_string << "Quantity" if (error_code.include?("03")) 
          error_string << "ScanInd" if (error_code.include?("04"))
          error_string << "CategoryCode" if (error_code.include?("05"))
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

        failure_items << { "itemnumber": gate_pass_item_params["item_number"].to_s, "errormsg": concat_error_messages }
      end      
    end

    

    if ((failure_item_count == 0) && gate_pass.valid?)
      if gate_pass.save
        if (success_item_error[:successmsg] == "null")
          success_item_error[:successmsg] = "DocumentNumber #{gate_pass.client_gatepass_number} is posted successfully."
        end
        success_items << success_item_error 
        failure_items << { "itemnumber": "null", "errormsg": "null" }
        document_hash = {"documentnumber": gate_pass.client_gatepass_number, "numberofitem": items_array.size.to_s, "successitemcount": success_item_count.to_s, "failureitemcount": failure_item_count.to_s, "failureitems": failure_items.flatten, "success": success_items.flatten}
        error_messages = document_hash
        return false, error_messages       
      else
        success_items << success_item_error
        success_item_count = 0
        document_hash = {"documentnumber": gate_pass.client_gatepass_number, "numberofitem": items_array.size.to_s, "successitemcount": success_item_count.to_s, "failureitemcount": failure_item_count.to_s, "failureitems": failure_items.flatten, "success": success_items.flatten}
        error_messages = document_hash
        return true, error_messages
      end
    elsif failure_item_count != 0
      success_items << success_item_error
      success_item_count = 0
      # failure_items.flat_map { |failure_item| failure_item[:errormsg] = "Not processed due to Master data issue in document" if failure_item[:errormsg] == "null" }
      document_hash = {"documentnumber": gate_pass.client_gatepass_number, "numberofitem": items_array.size.to_s, "successitemcount": success_item_count.to_s, "failureitemcount": failure_item_count.to_s, "failureitems": failure_items.flatten, "success": success_items.flatten}
      error_messages = document_hash
      return true, error_messages
    end
  end

  def self.create_return_gi_items(pickslip_details, gate_pass, errors_hash, destination, destination_error = nil, document_number_error = nil, document_type_error = nil, source_error = nil)
    gatepass_inventory_pending_receipt_status =  LookupValue.where("code = ?", Rails.application.credentials.gatepass_inventory_status_pending_receipt).first
    success_item_count = 0
    failure_item_count = 0
    failure_items = []
    success_items = []
    items_count = 0

    success_item_error = {"successmsg": "null"}
    pickslip_details.each do |pickslip_detail|
      items_count = items_count + pickslip_detail['item_list'].size
      pickslip_detail['item_list'].each do |gate_pass_item_params|
        error = false
        error_code = []
        client_sku_master = ClientSkuMaster.includes(:client_category, :sku_eans).where("code = ?", gate_pass_item_params["sku_code"]).last
        if gate_pass_item_params["sku_code"].blank?
          error = true
          error_code << "01"
        end
        if client_sku_master.nil?
          error = true
          error_code << "02"        
        end
        if gate_pass_item_params["quantity"].blank?
          error = true
          error_code << "03"        
        end
        if gate_pass_item_params["scan_id"].blank?
          error = true
          error_code << "04"        
        end
        if gate_pass_item_params["sku_category"].blank?
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
        if source_error.present? && ((source_error == "Source Code is missing") || (source_error == "Vendor Code is missing"))
          error = true
          error_code << "10"        
        elsif source_error.present? && source_error == "Source Code is not found in Blubirch system"
          error = true
          error_code << "11"
        end
        if gate_pass_item_params["item_number"].blank?
          error = true
          error_code << "12"
        end
        if error == false
          gate_pass.return_document_inventories.build(sku_code: gate_pass_item_params["sku_code"], scan_id: gate_pass_item_params["scan_id"],
                                                quantity: gate_pass_item_params["quantity"], item_description: (gate_pass_item_params["sku_description"].present? ? gate_pass_item_params["sku_description"] : client_sku_master.sku_description), 
                                                merchandise_category: (gate_pass_item_params["category_code"].present? ? gate_pass_item_params["category_code"] : client_sku_master.description["category_code_l3"]), merch_cat_desc: gate_pass_item_params["sku_description"],
                                                line_item: (gate_pass_item_params["category_code"].present? ? gate_pass_item_params["category_code"] : client_sku_master.description["category_code_l3"]),
                                                client_category_id: client_sku_master.client_category_id, brand: client_sku_master.brand, 
                                                client_category_name: client_sku_master.client_category.name, client_sku_master_id: client_sku_master.id,
                                                item_number: gate_pass_item_params["item_number"], inwarded_quantity: 0, status: gatepass_inventory_pending_receipt_status.original_code, 
                                                status_id: gatepass_inventory_pending_receipt_status.id, distribution_center_id: destination.id, 
                                                client_id: gate_pass.client_id, user_id: gate_pass.user_id, details: {"own_label"=> client_sku_master.own_label},
                                                pickslip_number: pickslip_detail["pickslip_number"], sku_eans: client_sku_master.sku_eans.collect(&:ean).flatten, imei_flag: (client_sku_master.try(:imei_flag).present? ? client_sku_master.try(:imei_flag) : "0"))
          success_item_count = success_item_count + 1
          # failure_items << { "itemnumber": gate_pass_item_params["item_number"].to_s, "errormsg": "null" }
        else
          failure_item_count = failure_item_count + 1
          
          concat_error_messages = "null"
          if error_code.present?
            error_string = []
            error_string << "Article" if (error_code.include?("01"))
            error_string << "Quantity" if (error_code.include?("03")) 
            error_string << "ScanInd" if (error_code.include?("04"))
            error_string << "CategoryCode" if (error_code.include?("05"))
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

          failure_items << { "itemnumber": gate_pass_item_params["item_number"].to_s, "errormsg": concat_error_messages }
        end
      end   
    end
    if ((failure_item_count == 0) && gate_pass.valid?)
      if gate_pass.save
        if (success_item_error[:successmsg] == "null")
          success_item_error[:successmsg] = "DocumentNumber #{gate_pass.client_gatepass_number} is posted successfully."
        end
        success_items << success_item_error
        failure_items << { "itemnumber": "null", "errormsg": "null" }
        document_hash = {"documentnumber": gate_pass.client_gatepass_number, "numberofitem": items_count.to_s, "successitemcount": success_item_count.to_s, "failureitemcount": failure_item_count.to_s, "failureitems": failure_items.flatten, "success": success_items.flatten }
        error_messages = document_hash
        return false, error_messages       
      else
        success_items << success_item_error
        success_item_count = 0
        document_hash = {"documentnumber": gate_pass.client_gatepass_number, "numberofitem": items_count.to_s, "successitemcount": success_item_count.to_s, "failureitemcount": failure_item_count.to_s, "failureitems": failure_items.flatten, "success": success_items.flatten }
        error_messages = document_hash
        return true, error_messages
      end
    elsif failure_item_count != 0
      success_items << success_item_error
      success_item_count = 0
      # failure_items.flat_map { |failure_item| failure_item[:errormsg] = "Not processed due to Master data issue in document" if failure_item[:errormsg] == "null" }
      document_hash = {"documentnumber": gate_pass.client_gatepass_number, "numberofitem": items_count.to_s, "successitemcount": success_item_count.to_s, "failureitemcount": failure_item_count.to_s, "failureitems": failure_items.flatten, "success": success_items.flatten }
      error_messages = document_hash
      return true, error_messages
    end
  end

  def self.prepare_error_message(message)
    return {message: message}
  end

  def self.prepare_item_error_message(article, message)
    return {article: article, message: message}
  end

  def self.generate_inbound_doc_report(user = nil, start_date = nil, end_date = nil, inbound_receiving_sites, inbound_supplying_sites)
    begin
      if inbound_receiving_sites.present? && inbound_supplying_sites.present?
        source_ids = DistributionCenter.where("code in (?)", inbound_supplying_sites).collect(&:id)
        destination_ids = DistributionCenter.where("code in (?)", inbound_receiving_sites).collect(&:id)
      elsif inbound_receiving_sites.present?
        destination_ids = DistributionCenter.where("code in (?)", inbound_receiving_sites).collect(&:id)
      elsif inbound_supplying_sites.present?
        source_ids = DistributionCenter.where("code in (?)", inbound_supplying_sites).collect(&:id)
      elsif user.present?
        destination_ids = user.distribution_centers.pluck(:id) if user.present?
      end
      if source_ids.present? && destination_ids.present?        
        gate_passes = GatePass.includes(gate_pass_inventories: [inventories: [:user]]).where("gate_passes.is_forward = ? and gate_passes.source_id in (?) and gate_passes.destination_id in (?) and gate_passes.document_submitted_time >= ? and gate_passes.document_submitted_time <= ?", true, source_ids, destination_ids, Time.parse(start_date).beginning_of_day - 5.5.hours, Time.parse(end_date).end_of_day - 5.5.hours)
      elsif source_ids.present?
        gate_passes = GatePass.includes(gate_pass_inventories: [inventories: [:user]]).where("gate_passes.is_forward = ? and gate_passes.source_id in (?) and gate_passes.document_submitted_time >= ? and gate_passes.document_submitted_time <= ?", true, source_ids, Time.parse(start_date).beginning_of_day - 5.5.hours, Time.parse(end_date).end_of_day - 5.5.hours)
      elsif destination_ids.present?
        gate_passes = GatePass.includes(gate_pass_inventories: [inventories: [:user]]).where("gate_passes.is_forward = ? and gate_passes.destination_id in (?) and gate_passes.document_submitted_time >= ? and gate_passes.document_submitted_time <= ?", true, destination_ids, Time.parse(start_date).beginning_of_day - 5.5.hours, Time.parse(end_date).end_of_day - 5.5.hours)
      else        
        gate_passes = GatePass.includes(gate_pass_inventories: [inventories: [:user]]).where("gate_passes.is_forward = ? and gate_passes.document_submitted_time >= ? and gate_passes.document_submitted_time <= ?", true,Time.parse(start_date).beginning_of_day - 5.5.hours, Time.parse(end_date).end_of_day - 5.5.hours)
      end
      file_csv = CSV.generate do |csv|
        csv << ["Document Number", "Document Type", "Source Code", "Destination Code", "Assigned Username", "Status", "Item Number", "Article", "Article Description",
                "Merchandise Category","Scan Ind", "Expected Quantity", "Scan Quantity", "Short Quantity", "EAN", "Serial Number", "IMEI1", "IMEI2",
                "Short Reason", "Pickslip Number", "User", "Scanning DateTme"]


        gate_passes.each_with_index do |gate_pass, index|
          if gate_pass.document_type == "IBD"
            source_code = gate_pass.vendor_code
          else
            source_code = gate_pass.source_code
          end
          if gate_pass.inventories.present? && gate_pass.gate_pass_inventories.present?          
            gate_pass.gate_pass_inventories.each do |gate_pass_inventory|
              gate_pass_inventory.inventories.each do |inventory|
                csv <<  [ gate_pass.client_gatepass_number, gate_pass.document_type, source_code, gate_pass.destination_code, gate_pass.try(:assigned_user).try(:username),
                          gate_pass.status, gate_pass_inventory.item_number, gate_pass_inventory.sku_code, gate_pass_inventory.item_description, gate_pass_inventory.merchandise_category, gate_pass_inventory.scan_id, gate_pass_inventory.quantity, inventory.quantity, inventory.short_quantity, inventory.details["ean"], inventory.serial_number, inventory.imei1, inventory.imei2, inventory.short_reason,
                          gate_pass_inventory.pickslip_number, inventory.try(:user).try(:username), inventory.try(:scanned_time)]
              end
            end
          end
        end
      end

      amazon_s3 = Aws::S3::Resource.new(region: Rails.application.credentials.aws_s3_region, access_key_id: Rails.application.credentials.access_key_id, secret_access_key: Rails.application.credentials.secret_access_key)

      bucket = Rails.application.credentials.aws_bucket

      time = Time.now.strftime("%F %H:%M:%S").to_s.tr('-', '')

      file_name = "inward_report_#{time.parameterize.underscore}"

      obj = amazon_s3.bucket(bucket).object("uploads/inbound_documents/#{file_name}.csv")

      obj.put(body: file_csv, acl: 'public-read', content_disposition: 'attachment', content_type: 'text/csv')

      url = obj.public_url
      
      return url
    rescue Exception => message
      Rails.logger.warn("----------Error in generating inbound report #{message.inspect}")
    end

  end

end
