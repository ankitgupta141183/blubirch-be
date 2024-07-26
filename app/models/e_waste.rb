class EWaste < ApplicationRecord
	acts_as_paranoid
	belongs_to :inventory
  belongs_to :client
  belongs_to :client_sku_master , optional: true
  belongs_to :distribution_center
  belongs_to :e_waste_order ,optional: true
  has_many :e_waste_histories
  before_save :default_alert_level
  # validates_uniqueness_of :tag_number, allow_blank: true, :case_sensitive => false, unless: :check_active

	def self.to_csv(user_id)
    user = User.find_by(id: user_id)
    if user.present?
      e_waste_pending_status = LookupValue.where(code: Rails.application.credentials.e_waste_status_pending_e_waste).first
      attributes = EWaste.column_names - ["id" , "created_at" , "updated_at" , "deleted_at" , "details"]
      attr1 = ["Category L1","Category L2","Category L3"]
      e_waste_order_attr = ["order_number"]
      CSV.generate(headers: true) do |csv|
      	csv << attr1 + attributes + e_waste_order_attr
        #csv << attributes

        EWaste.where(status_id: e_waste_pending_status.try(:id), distribution_center_id: user.distribution_centers).each do |item|
        	csv << attr1.map{|attr| item.client_sku_master.description[attr.parameterize.underscore] rescue nil} + attributes.map{ |attr| item.send(attr) } + e_waste_order_attr.map{ |attr| item.e_waste_order.send(attr) rescue nil }
        end
      end
    end
  end


  def self.check_for_errors(errors_hash,row_number,row,e_waste_item)    
    error2 = ""
    flag = 1 
    error_found = false

    if !e_waste_item.present?
      error2 = "E-Waste tag number doesnt exist"
      error_found = true
      error_row = prepare_error_hash(row,row_number,error2)
      errors_hash[row_number] << error_row
    end
    if e_waste_item.present? && e_waste_item.status == LookupValue.where(code:Rails.application.credentials.e_waste_status_pending_e_waste_dispatch).first.original_code
      error2 = "The inventory already belongs to an existing lot"
      error_found = true
      error_row = prepare_error_hash(row, row_number, error2)
      errors_hash[row_number] << error_row
    end
    if !row["Category L1"].present?
      error2 = "Category L1 cannot be blank"
      error_found = true
      error_row = prepare_error_hash(row, row_number, error2)
      errors_hash[row_number] << error_row
    end
    if !row["Category L2"].present?
      error2 = "Category L2 cannot be blank"
      error_found = true
      error_row = prepare_error_hash(row, row_number, error2)
      errors_hash[row_number] << error_row
    end
    if !row["Category L3"].present?
      error2 = "Category L3 cannot be blank"
      error_found = true
      error_row = prepare_error_hash(row, row_number, error2)
      errors_hash[row_number] << error_row
    end
    if !row["inventory_id"].present?
      error2 = "Inventory ID cannot be blank"
      error_found = true
      error_row = prepare_error_hash(row, row_number, error2)
      errors_hash[row_number] << error_row
    end
    if !row["client_sku_master_id"].present?
      error2 = "Client SKU Master ID cannot be blank"
      error_found = true
      error_row = prepare_error_hash(row, row_number, error2)
      errors_hash[row_number] << error_row
    end
    if !row["sku_code"].present?
      error2 = "SKU Code cannot be blank"
     error_found = true
      error_row = prepare_error_hash(row, row_number, error2)
      errors_hash[row_number] << error_row 
    end
    if !row["item_description"].present?
      error2 = "Item description cannot be blank"
      error_found = true
      error_row = prepare_error_hash(row, row_number, error2)
      errors_hash[row_number] << error_row 
    end
    if !row["sr_number"].present?
      error2 = "SR Number cannot be blank"
      error_found = true
      error_row = prepare_error_hash(row, row_number, error2)
      errors_hash[row_number] << error_row
    end
    if !row["location"].present?
      error2 = "Location cannot be blank"
      error_found = true
      error_row = prepare_error_hash(row, row_number, error2)
      errors_hash[row_number] << error_row
    end
    if !row["brand"].present?
      error2 = "Brand cannot be blank"
      error_found = true
      error_row = prepare_error_hash(row, row_number, error2)
      errors_hash[row_number] << error_row
    end
    if !row["grade"].present?
      error2 = "Grade cannot be blank"
      error_found = true
      error_row = prepare_error_hash(row, row_number, error2)
      errors_hash[row_number] << error_row 
    end
    if !row["lot_name"].present?
      error2 = "Lot Name cannot be blank"
      error_found = true
      error_row = prepare_error_hash(row, row_number, error2)
      errors_hash[row_number] << error_row
    end
    if !row["mrp"].present?
      error2 = "MRP cannot be blank"
      error_found = true
      error_row = prepare_error_hash(row, row_number, error2)
      errors_hash[row_number] << error_row
    end
    if !row["sales_price"].present?
      error2 = "Sales Price cannot be blank"
      error_found = true
      error_row = prepare_error_hash(row, row_number, error2)
      errors_hash[row_number] << error_row
    end
    if !row["order_number"].present?
      error2 = "Order Number cannot be blank"
      error_found = true
      error_row = prepare_error_hash(row, row_number, error2)
      errors_hash[row_number] << error_row 
    end
    if EWasteOrder.find_by(order_number: row["order_number"]).present?
      error2 = "Order Number already exists"
      error_found = true
      error_row = prepare_error_hash(row, row_number, error2)
      errors_hash[row_number] << error_row 
    end

    return error_found , errors_hash
  end

  def self.prepare_error_hash(row, rownumber, message)
    message = "Error In row number (#{rownumber}) : " + message.to_s
    return {row: row, row_number: rownumber, message: message}
  end

  def self.import_lots(e_waste_file_upload_id)
    errors_hash = Hash.new(nil)
    error_found = false
    e_waste_file_upload = EWasteFileUpload.where("id = ?", e_waste_file_upload_id).first
    data = CSV.read(e_waste_file_upload.e_waste_file.path, {headers: true, encoding: "iso-8859-1:utf-8"})
    user = User.find(e_waste_file_upload.user_id)
  	#data = CSV.read(file.path, {headers: true, encoding: "iso-8859-1:utf-8"})
  	headers = data.headers
  	warehouse_order = {}
    new_e_waste_status = LookupValue.find_by(code:Rails.application.credentials.e_waste_status_pending_e_waste_dispatch)
    begin
      EWaste.transaction do 
      	data.each_with_index do |row, index|
          row_number = index + 1
          errors_hash.merge!(row_number => [])
          move_to_next = false   
          e_waste_item = EWaste.find_by(tag_number: row["tag_number"])   
          move_to_next , errors_hash = EWaste.check_for_errors(errors_hash,row_number,row,e_waste_item) 

          if move_to_next
            error_found = true
          end
          next if move_to_next
      		if row["order_number"].present? && row["vendor_code"].present?
    	  		e_waste_order = EWasteOrder.find_by(order_number: row["order_number"], vendor_code: row["vendor_code"])
    	  		if e_waste_order.present?   	  			
    	  			e_waste_order.update(order_amount: e_waste_order.order_amount.to_i + row["sales_price"].to_i)
    	  			warehouse_order = WarehouseOrder.find_by(orderable_id: e_waste_order.id , orderable_type: "E-WasteOrder")
    	  			warehouse_order.update(total_quantity: e_waste_order.order_amount)
    	  		else
    	  			e_waste_order = EWasteOrder.create(order_number: row["order_number"], vendor_code: row["vendor_code"],order_amount: row["sales_price"].to_i)
    	  			warehouse_order = WarehouseOrder.create(orderable: e_waste_order,total_quantity: e_waste_order.order_amount, distribution_center_id:row["distribution_center_id"].to_i,status_id:LookupValue.find_by(code:Rails.application.credentials.order_status_warehouse_pending_pick).id,vendor_code:row["vendor_code"])
    	  		end

    	  		e_waste_item = EWaste.find_by(tag_number: row["tag_number"])
    	  		e_waste_item.update(lot_name: row["lot_name"] , sales_price: row["sales_price"], e_waste_order_id: e_waste_order.id, status: new_e_waste_status.original_code , status_id: new_e_waste_status.id)
    	  		client_sku_master = e_waste_item.client_sku_master
    	  		client_category = client_sku_master.client_category
    	  		WarehouseOrderItem.create(warehouse_order_id: warehouse_order.id , inventory_id: e_waste_item.inventory_id , client_category_id: client_category.id , client_category_name: client_category.name , sku_master_code: client_sku_master.code ,item_description: e_waste_item.item_description , tag_number: e_waste_item.tag_number , serial_number: e_waste_item.inventory.serial_number , aisle_location: e_waste_item.aisle_location , quantity: e_waste_item.sales_price , status_id: LookupValue.find_by(code:Rails.application.credentials.order_status_warehouse_pending_pick).id, status: LookupValue.find_by(code:Rails.application.credentials.order_status_warehouse_pending_pick).original_code)
      		end
      		
      	end
      end

    ensure
      if error_found
        all_error_messages = errors_hash.values.flatten.collect do |h| h[:message].to_s end
        all_error_message_str = all_error_messages.join(',')
        
        e_waste_file_upload.update(status: "Halted", remarks: all_error_message_str) if e_waste_file_upload.present?
        return false
      else
        all_error_messages = errors_hash.values.flatten.collect do |h| h[:message].to_s end
        all_error_message_str = all_error_messages.join(',')
       
        e_waste_file_upload.update(status: "Completed") if e_waste_file_upload.present?
        return true
      end
    end
  end


  def self.import_inventories
  	Inventory.where(disposition: "E-Waste").each do |i|
      EWasteOrder.create_record(i)  		
  	end
  end


  def self.create_record(inventory, user_id)
    user = User.find_by_id(user_id)
    e_waste_pending_status = LookupValue.where(code:Rails.application.credentials.e_waste_status_pending_e_waste).first
    client_sku_master = ClientSkuMaster.where(client_category_id: inventory.client_category_id).first 
    e_waste_item = EWaste.new( inventory_id: inventory.id, tag_number: inventory.tag_number , 
                                        item_description: inventory.item_description, sr_number: inventory.sr_number,serial_number: inventory.serial_number , serial_number_2:inventory.serial_number_2, toat_number: inventory.toat_number ,item_price: inventory.item_price, 
                                        client_tag_number: inventory.client_tag_number, client_id:inventory.client_id, aisle_location:inventory.aisle_location,
                                        location: inventory.details["destination_code"], grade: inventory.grade,  distribution_center_id: inventory.distribution_center_id, details: inventory.details, 
                                        status_id: e_waste_pending_status.try(:id), status: e_waste_pending_status.try(:original_code), sku_code: inventory.sku_code, brand: inventory.details["brand"], mrp: client_sku_master.try(:mrp),
                                        client_sku_master_id: client_sku_master.id, client_category_id: inventory.try(:client_category_id))
    e_waste_item.details["criticality"] = "Low"
    if e_waste_item.save
      e_waste_history = EWasteHistory.new(e_waste_id:e_waste_item.id , status_id: e_waste_pending_status.try(:id), status: e_waste_pending_status.try(:original_code))
      e_waste_history.details = {}
      key = "#{e_waste_pending_status.original_code.try(:downcase).try(:strip).split(' ').join('_')}_created_at"
      e_waste_history.details[key] = Time.now
      e_waste_history.details["status_changed_by_user_id"] = user.id
      e_waste_history.details["status_changed_by_user_name"] = user.full_name
      e_waste_history.save
    end
    
  end

  def call_log_or_claim_date
    self.claim_email_date.to_date.strftime("%d/%b/%Y") rescue ''
  end

  def visit_date
    self.brand_inspection_date.to_date.strftime("%d/%b/%Y") rescue ''
  end

  def resolution_date_time
    self.resolution_date.to_date.strftime("%d/%b/%Y") rescue ''
  end
  
  def default_alert_level
    if status_changed? || status_id_changed?
      self.details['criticality'] = 'Low'
    end
  end

  def check_active
    return true if self.inventory.e_wastes.where.not(id: self.id).blank?
    return self.inventory.e_wastes.where.not(id: self.id).where(is_active: true).blank?
  end
end
