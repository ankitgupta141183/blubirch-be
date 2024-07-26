class PendingReceiptDocument < ApplicationRecord
  acts_as_paranoid
  belongs_to :receiving_site, class_name: 'DistributionCenter', foreign_key: "receiving_site_id", optional: true
  has_many :pending_receipt_document_items
  
  IRRD_TYPES = ['Purchase Order', 'Lease Procurement Order', 'Return (Inward) Order', 'Transfer Order', 'Repair Order', 'Replacement Order']

  def self.import_file(master_file_upload)
    errors_hash = Hash.new
    error_found = false
    temp_file = open(master_file_upload.master_file.url)
    file = File.new(temp_file)
    data = CSV.read(file, headers: true, encoding: 'iso-8859-1:utf-8')
    user = master_file_upload.user
    headers = data.headers
    unless headers.include?('Tag Number') && headers.include?('SKU Code')
      error_found = true
      errors_hash[0] = [{ row_number: 0, message: "Invalid File! Please upload valid file." }]
    end
    if data.size < 1
      error_found = true
      errors_hash[0] = [{ row_number: 0, message: "No data present. Please add some data." }]
    end
    prd_status_incomplete = LookupValue.find_by(code: 'prd_status_incomplete')
    prd_status_open = LookupValue.find_by(code: 'prd_status_open')
    begin
      raise "" if error_found
      ActiveRecord::Base.transaction do
        data.each_with_index do |row, index|
          next if row['SKU Code'].blank? && row['Category Code'].blank?
          row_number = index + 2
          errors_hash.merge!(row_number => [])
          
          pending_receipt_document = self.find_by({
            inward_reference_document_number: row['Inward Reference Document Number'], inward_reason_reference_document_number: row['Inward Reason Reference Document Number'],
            consignee_reference_document_number: row['Consignee Reference Document Number'], vendor_reference_document_number: row['Vendor Reference Document Number'], batch_number: master_file_upload.id
          })
          pending_receipt_document = create_prd(row, user.id, master_file_upload.id) if pending_receipt_document.blank?
          
          error_found, errors_hash, data = check_for_errors(errors_hash, row_number, row)
          client_sku_master, client_category, vedor_master, receiving_site, client = data

          next "" if error_found
  
          prd_status = if row['Inward Reference Document Number'].present? && row['Inward Reference Document Type'].present? && row['Inward Reference Document Date'].present? && row['Sales Price'].present?
            prd_status_open
          else
            prd_status_incomplete
          end
  
          quantity = row['Quantity'].to_i
          
          quantity.times do |i|
            prd_item = pending_receipt_document.pending_receipt_document_items.new({
              client_id: client.id, client_category_id: client_category.id, client_sku_master_id: client_sku_master.id, box_number: row['Box Number'], vendor_id: vedor_master.id,
              tag_number: row['Tag Number'], ean: client_sku_master.ean, brand: client_sku_master.brand, grade: row['Grade'].present? ? row['Grade'] : 'Not Tested', model: row['Model'], imei_flag: row['IMEI Flag'],
              scan_indicator: row['Scan Indicator'], serial_number1: row['Serial Number 1'], serial_number2: row['Serial Number 2'], sku_code: client_sku_master.code,
              sku_description: client_sku_master.sku_description, category_code: client_category.code, category_details: client_sku_master.description, quantity: 1,
              mrp: row['MRP'], asp: row['ASP'], sales_price: row['Sales Price'], map: row['MAP'], purchase_price: row['Purchase Price'], customer_name: row['Customer Name'],
              customer_mobile: row['Customer Mobile'], customer_email: row['Customer Email'], customer_city: row['Customer City'], customer_address_1: row['Customer Address 1'],
              customer_address_2: row['Customer Address 2'], customer_state: row['Customer State'], customer_pincode: row['Customer Pincode'], supplying_site: row['Supplying Site'], supplier_organization: row['Supplying Organization'],
              receiving_site_id: receiving_site.id, receiving_site: receiving_site.code, receiving_organization: client.name, status: prd_status.original_code,
              status_id: prd_status.id, user_id: user.id, distribution_center_id: receiving_site.id, buyer_available: row['Buyer Available'] == 'Y', grading_required: row['Grading Required'] == 'Y'
            })
            prd_item.disposition = if prd_item.buyer_available
              'Saleable'
            else
              'Liquidation'
            end
            prd_item.save!
              
            pending_receipt_document.update_attribute(:is_box_mapped, true) if prd_item.box_number.present? && !pending_receipt_document.is_box_mapped?
          end
        end
        raise "" if errors_hash.values.flatten.collect { |h| h[:message].to_s }.present?
      end
    rescue Exception => ex
      error_found = true
      row_number = errors_hash.keys.last
      errors_hash[row_number] << { row_number: row_number, message: ex.message }
      raise ActiveRecord::Rollback
    ensure
      all_error_messages = errors_hash.values.flatten.collect { |h| h[:message].to_s }
      all_error_message_str = all_error_messages.reject(&:blank?).join(', ')
      
      if error_found
        master_file_upload.update(status: 'Halted', remarks: all_error_message_str) if master_file_upload.present?
        return false
      else
        master_file_upload.update(status: 'Completed') if master_file_upload.present?
        return true
      end
    end
  end
  
  def self.update_prd_items(master_file_upload)
    errors_hash = Hash.new
    error_found = false
    temp_file = open(master_file_upload.master_file.url)
    file = File.new(temp_file)
    data = CSV.read(file, headers: true, encoding: 'iso-8859-1:utf-8')
    user = master_file_upload.user
    headers = data.headers
    unless headers.include?('PRD No.') && headers.include?('Tag Number')
      error_found = true
      errors_hash[0] = [{ row_number: 0, message: "Invalid File! Please upload valid file." }]
    end
    prd_status_open = LookupValue.find_by(code: 'prd_status_open')
    begin
      raise "" if error_found
      ActiveRecord::Base.transaction do
        data.each_with_index do |row, index|
          next if row['SKU Code'].blank? && row['Category Code'].blank?
          row_number = index + 2
          errors_hash.merge!(row_number => [])
          
          prd_item = PendingReceiptDocumentItem.find_by(prd_number: row['PRD No.'])
          raise "Invalid PRD No." if prd_item.blank?
          
          error_found, errors_hash, data = check_for_errors(errors_hash, row_number, row, prd_item)
          client_sku_master, client_category, vedor_master, receiving_site, client = data

          raise "" if error_found
  
          prd_item.assign_attributes({
            box_number: row['Box Number'], vendor_id: vedor_master.id, tag_number: row['Tag Number'], model: row['Model'], imei_flag: row['IMEI Flag'],
            scan_indicator: row['Scan Indicator'], serial_number1: row['Serial Number 1'], serial_number2: row['Serial Number 2'],
            mrp: row['MRP'], asp: row['ASP'], sales_price: row['Sales Price'], map: row['MAP'], purchase_price: row['Purchase Price'], customer_name: row['Customer Name'],
            customer_mobile: row['Customer Mobile'], customer_email: row['Customer Email'], customer_city: row['Customer City'], customer_address_1: row['Customer Address 1'],
            customer_address_2: row['Customer Address 2'], customer_state: row['Customer State'], customer_pincode: row['Customer Pincode'],
            receiving_site_id: receiving_site.id, receiving_site: receiving_site.code, supplying_site: row['Supplying Site'], supplier_organization: row['Supplying Organization'],
            receiving_organization: client.name, distribution_center_id: receiving_site.id
          })
          prd_item.assign_attributes({status: prd_status_open.original_code, status_id: prd_status_open.id})
          prd_item.save!
          
          pending_receipt_document = prd_item.pending_receipt_document
          pending_receipt_document.update_attribute(:is_box_mapped, true) if prd_item.box_number.present? && !pending_receipt_document.is_box_mapped?
        end
      end
    rescue Exception => ex
      error_found = true
      row_number = errors_hash.keys.last
      errors_hash[row_number] << { row_number: row_number, message: ex.message }
      raise ActiveRecord::Rollback
    ensure
      all_error_messages = errors_hash.values.flatten.collect { |h| h[:message].to_s }
      all_error_message_str = all_error_messages.reject(&:blank?).join(', ')
      
      if error_found
        master_file_upload.update(status: 'Halted', remarks: all_error_message_str) if master_file_upload.present?
        return false
      else
        master_file_upload.update(status: 'Completed') if master_file_upload.present?
        return true
      end
    end
  end
  
  def self.create_prd(row, user_id, batch_id)
    receiving_site = DistributionCenter.find_by(code: row['Receiving Site'])
    prd_created_status = LookupValue.find_by(code: 'prd_status_prd_created')
    
    pending_receipt_document = self.new({
      inward_reference_document_type: row['Inward Reference Document Type'], inward_reference_document_number: row['Inward Reference Document Number'],
      inward_reason_reference_document_type: row['Inward Reason Reference Document Type'], inward_reason_reference_document_number: row['Inward Reason Reference Document Number'],
      consignee_reference_document_type: row['Consignee Reference Document Type'], consignee_reference_document_number: row['Consignee Reference Document Number'],
      vendor_reference_document_number: row['Vendor Reference Document Number'], inward_reference_document_date: row['Inward Reference Document Date'],
      inward_reason_reference_document_date: row['Inward Reason Reference Document Date'], supplying_site_code: row['Supplying Site'], receiving_site_id: receiving_site&.id,
      receiving_site_code: receiving_site&.code, supplier_organization: row['Supplying Organization'], status: prd_created_status.original_code, status_id: prd_created_status.id
    })
    pending_receipt_document.batch_number = batch_id
    pending_receipt_document.user_id = user_id
    pending_receipt_document.save!
    
    pending_receipt_document
  end
  
  MANDATORY_FIELDS = ['Inward Reason Reference Document Number', 'Inward Reason Reference Document Date', 'Quantity', 'Brand', 'MRP', 'Buyer Available', 'Grading Required']
  def self.check_for_errors(errors_hash, row_number, row, prd_item = nil)
    error = ''
    error_found = false

    # Validate mandatory fields
    missing_feilds = []
    MANDATORY_FIELDS.each do |field|
      if row[field].blank?
        error_found = true
        missing_feilds << field
      end
    end
    if error_found
      message = "#{missing_feilds.join(', ')} is/are mandatory"
      error_row = prepare_error_hash(row_number, message)
      errors_hash[row_number] << error_row
      return [error_found, errors_hash, []]
    end
    
    # Validate IRRD type
    unless ['Y', 'N'].include? row['Buyer Available'].to_s
      error_found = true
      error_row = prepare_error_hash(row_number, 'Invalid value for Buyer Available')
      errors_hash[row_number] << error_row
    end
    
    # Validate IRRD type
    unless IRRD_TYPES.include? row['Inward Reason Reference Document Type'].to_s
      error_found = true
      error_row = prepare_error_hash(row_number, 'Invalid IRRD Type')
      errors_hash[row_number] << error_row
    end
    
    # Validate Quantity
    if row['Quantity'].to_i <= 0
      error_found = true
      error_row = prepare_error_hash(row_number, 'Invalid Quantity')
      errors_hash[row_number] << error_row
    end
    
    # Validate VRN / CRN
    # if row['Vendor Reference Document Number'].blank? && row['Consignee Reference Document Number'].blank?
    #   error_found = true
    #   error_row = prepare_error_hash(row_number, 'Either Vendor Reference Number or Consignee Reference Number should be present')
    #   errors_hash[row_number] << error_row
    # end
    
    # validate sku code
    client_sku_master = ClientSkuMaster.find_by(code: row['SKU Code'])
    if client_sku_master.blank? && prd_item.nil?
      error_found = true
      error_row = prepare_error_hash(row_number, 'Invalid SKU Code')
      errors_hash[row_number] << error_row
    end
    client_category = client_sku_master&.client_category
    
    # validate SKU Description
    if client_sku_master&.sku_description != row['SKU Description'].to_s && prd_item.nil?
      error_found = true
      error_row = prepare_error_hash(row_number, 'Invalid SKU Description')
      errors_hash[row_number] << error_row
    end
    
    # validate Category code
    if client_category&.name != row['Category Code'].to_s && prd_item.nil?
      error_found = true
      error_row = prepare_error_hash(row_number, 'Invalid Category Code, Category Code should be linked to SKU Code')
      errors_hash[row_number] << error_row
    end

    # validate supplier / vendor
    supplier = row['Supplier'].to_s.downcase
    vedor_master = VendorMaster.where('lower(vendor_name) = ? OR lower(vendor_code) = ?', supplier, supplier).first
    if vedor_master.blank? || row['Supplier'].blank?
      error_found = true
      error_row = prepare_error_hash(row_number, 'Invalid Supplier')
      errors_hash[row_number] << error_row
    end
    
    # validate Supplying Organization
    supplying_rganization = ClientProcurementVendor.find_by(vendor_code: row['Supplying Organization'])
    if supplying_rganization.blank?
      supplying_rganization = DistributionCenter.find_by(code: row['Supplying Organization'])
      if supplying_rganization.blank?
        error_found = true
        error_row = prepare_error_hash(row_number, 'Invalid Supplying Organization')
        errors_hash[row_number] << error_row
      end
    end
    
    # validate receiving site 
    receiving_site = DistributionCenter.find_by(code: row['Receiving Site'])
    if receiving_site.blank?
      error_found = true
      error_row = prepare_error_hash(row_number, 'Invalid Receiving Site')
      errors_hash[row_number] << error_row
    end
    
    # validate receiving organization / client 
    client = Client.find_by(name: row['Receiving Organization'])
    if client.blank?
      error_found = true
      error_row = prepare_error_hash(row_number, 'Invalid Receiving Organization')
      errors_hash[row_number] << error_row
    end

    [error_found, errors_hash, [client_sku_master, client_category, vedor_master, receiving_site, client]]
  end
  
  def self.prepare_error_hash(row_number, message)
    message = "Error in row number (#{row_number}): " + message.to_s
    { row_number: row_number, message: message }
  end
  
  def generate_grn(user)
    prd_closed_status = LookupValue.find_by(code: 'prd_status_closed')
    grn_submitted_status = LookupValue.find_by(code: 'prd_status_grn_submitted')
    prd_items = pending_receipt_document_items.where(status_id: prd_closed_status.id)
    
    grn_submitted_date = Date.current
    grn_number = SecureRandom.hex(3) + grn_submitted_date.strftime("%Y%m%d")
    grn_submitted_user_id = user.id
    grn_submitted_user_name = user.username
    prd_items.each do |prd_item|
      prd_item.assign_attributes({
        grn_submitted_date: grn_submitted_date, grn_number: grn_number, grn_submitted_user_id: grn_submitted_user_id, grn_submitted_user_name: grn_submitted_user_name
      })
      prd_item.save!
      prd_item.update_inventory
      prd_item.assign_dispotion
    end
    self.update!(status: grn_submitted_status.original_code, status_id: grn_submitted_status.id)
  end
  
end
