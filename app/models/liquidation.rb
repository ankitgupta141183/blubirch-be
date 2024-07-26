class Liquidation < ApplicationRecord
  acts_as_paranoid
  belongs_to :inventory
  belongs_to :client
  belongs_to :client_sku_master , optional: true
  belongs_to :distribution_center
  belongs_to :liquidation_order ,optional: true
  has_many :liquidation_histories
  before_save :default_alert_level
  belongs_to :liquidation_request,optional: true
  belongs_to :client_category, optional: true
  has_many :ecom_request_histories
  has_many :ecom_liquidations

  scope :filter_by_category, -> (category_ids){ where(client_category_id: category_ids) }
  scope :filter_by_grade, -> (grades){ where("liquidations.grade IN (?)", grades) }
  scope :filter_by_ewaste, -> (params){ where("liquidations.is_ewaste IN (?)", params.map!{ |param| param == 'Not defined' ? '' : param }) }
  enum is_ewaste: {yes: 'Yes', no: 'No', not_defined: ''}
  enum b2c_publish_status: { publish_initiated: 1, publish_approval: 2, published: 3, failed: 4 }, _prefix: true
  # validates_uniqueness_of :tag_number, allow_blank: true, :case_sensitive => false, unless: :check_active

  include JsonUpdateable
  include LiquidationSearchable
  include Filterable

	def self.to_csv(user_id)
    liquidation_pending_status = LookupValue.where(code:Rails.application.credentials.liquidation_pending_status).first
    user = User.find(user_id)
    attributes = Liquidation.column_names - ["id" , "created_at" , "updated_at" , "deleted_at" , "details"]
    attr1 = ["Category L1","Category L2","Category L3"]
    liquidation_order_attr = ["order_number"]
    CSV.generate(headers: true) do |csv|
    	csv << attr1 + attributes + liquidation_order_attr
      #csv << attributes

      Liquidation.where(status: liquidation_pending_status.try(:original_code), distribution_center_id: user.distribution_centers).each do |item|
      	csv << attr1.map{|attr| item.client_sku_master.description[attr.parameterize.underscore] rescue nil} + attributes.map{ |attr| item.send(attr) } + liquidation_order_attr.map{ |attr| item.liquidation_order.send(attr) rescue nil }
      end
    end
  end

  def set_disposition(disposition, current_user = nil)
    begin
      ActiveRecord::Base.transaction do
        inventory = self.inventory
        self.details['disposition_set'] = true
        self.is_active = false
        inventory.disposition = disposition
        inventory.save

        if self.save!
          create_history(current_user)
        end
        self.update_inventory_status(disposition)
        DispositionRule.create_bucket_record(disposition, inventory, 'Liquidation', current_user&.id)
      end
    rescue ActiveRecord::RecordInvalid => exception
      render json: "Something Went Wrong", status: :unprocessable_entity
      return
    end
  end

  def create_history(current_user)
    liquidation_history = self.liquidation_histories.new
    liquidation_history.status = self.status
    liquidation_history.status_id = self.status_id
    liquidation_history.details = { "status" => self.status, "status_changed_by_user_id" => current_user&.id, "status_changed_by_user_name" => current_user&.full_name }
    liquidation_history.save!
  end

  def update_inventory_status(code)
    inventory = self.inventory
    lookup_key = LookupKey.find_by(code: "WAREHOUSE_DISPOSITION")
    bucket_status = lookup_key.lookup_values.find_by(original_code: code)
    raise CustomErrors.new "Invalid code." if bucket_status.blank?
    inventory.update_inventory_status!(bucket_status)
  end

  def self.export(user_id, ids=nil)
    liquidation_pending_status = LookupValue.where(code:Rails.application.credentials.liquidation_status_pending_lot_creation_status).first
    liquidation_pending_rfq_status = LookupValue.where(code: Rails.application.credentials.liquidation_status_pending_rfq_status).first
    statuses = [liquidation_pending_status.try(:original_code), liquidation_pending_rfq_status.try(:original_code)]
    user = User.find(user_id)
    if ids.present?
      ids = JSON.parse(ids)
      @liquidations = Liquidation.includes(:client_sku_master, inventory: [:inventory_grading_details]).where(status: statuses, id: ids, is_active: true)
    else
      @liquidations = Liquidation.includes(:client_sku_master, inventory: [:inventory_grading_details]).where(status: statuses, distribution_center_id: user.distribution_centers, is_active: true)
    end
    # attributes = Liquidation.column_names - ["id" , "created_at" , "updated_at" , "deleted_at" , "details"]
    # attr1 = ["Category L1","Category L2","Category L3"]
    # liquidation_order_attr = ["order_number"]
    attributes = [
    "SR Number/BAN Number", "RPA Site Location" ,"Article", "Description" , 
    "Brand" , "Class Description", "serial_number","Policy",
    "Grade","Expected Price","Receiving Store Code", "Customer Use(Y/N)",
    "Reason For Inward at RPA Hub", "Brand Call ID","DT/CN/Claim Amount","Electrically OK",
    "Dents/Scratches","Accessories Available","Packing box","Supplying Store Code",
    "Category L1","Qty", "Tag Number", "Transaaction ID", "Serial Number 2", "Inwarded At", "Created By",
    "Remark", "Images", "Lot Name", "MRP", "Floor Price"]
    file_csv = CSV.generate(headers: true) do |csv|
      csv <<  attributes 
      @liquidations.each do |item| 
        if item.client_sku_master.present?
          categoryl1 = item.client_sku_master.description['category_l1']
          item_type = item.client_sku_master.item_type
        else
          categoryl1 = ""
          item_type = ""
        end
        source_code = item.inventory.details['source_code'] rescue ''
        customer_use = ((item.inventory.inventory_grading_details.where(is_active: true).last.details['final_grading_result']['Item Condition'].first["value"] == 'Unused') ? "No" : "Yes" ) rescue 'NA'
        return_reason = item.inventory.return_reason
        call_log_id = (item.inventory.vendor_return.present? ? item.inventory.vendor_return.call_log_id : 'NA')

        dents_scrathes = item.inventory.inventory_grading_details.where(is_active: true).last.details['final_grading_result']['Physical'].first["value"] rescue 'NA'
        accessories = item.inventory.inventory_grading_details.where(is_active: true).last.details['final_grading_result']['Accessories'].first["value"] rescue 'NA'
        packing = item.inventory.inventory_grading_details.where(is_active: true).last.details['final_grading_result']["Packaging"].first['value'] rescue 'NA'
        electrically  = item.inventory.inventory_grading_details.where(is_active: true).last.details['final_grading_result']["Functional"].first['value'] rescue 'NA'
        inward_date = item.inventory.details["inward_grading_time"].to_datetime.strftime("%d/%b/%Y %I:%M:%S %p") rescue "NA"
        username = item.details['inward_user_name']
        images = []
        item.inventory.inventory_grading_details.each do |detail|
          ((detail.details["final_grading_result"]["Packaging"] rescue nil) || []).each do |t|
            images << t["annotations"].map{|x| x["src"]} rescue []
          end
          ((detail.details["final_grading_result"]["Item Condition"] rescue nil) || []).each do |t|
            images << t["annotations"].map{|x| x["src"]} rescue []
          end
        end

        images = images.flatten.present? ? images.flatten.join("\n") : ''

        remark = ''

        grading_detail = item.inventory.inventory_grading_details.last.details['final_grading_result'] rescue ''

        if grading_detail.present?

          grading_detail.each do |k, value|
            substring = ''
            value.each_with_index do |updated, i|
              if k == 'Functional'
                substring += " #{updated['test']} - #{updated['value']}, "
              elsif k == 'Physical'
                substring += "#{grading_detail['Item Condition'][0]['annotations'][i]['orientation']}: " if (grading_detail['Item Condition'][0]['annotations'][i]['orientation'].present? rescue false)
                substring += "#{updated['output']}, "
              else
                substring += "#{updated['output']} "
              end
            end
            remark += "#{k}: #{substring} \n "
          end
        end

        csv << [
          item.sr_number, item.location, item.sku_code, item.item_description,
          item.brand, item_type, item.serial_number, item.details['policy_type'], 
          item.grade,item.sales_price,source_code,customer_use,
          return_reason, call_log_id,"NA",electrically,
          dents_scrathes,accessories, packing, source_code,
          categoryl1,1, item.tag_number, item.details["transaction_id"],
          item.serial_number_2, inward_date, username, remark, images, '', item.item_price, item.floor_price]
      end
    end

      amazon_s3 = Aws::S3::Resource.new(region: Rails.application.credentials.aws_s3_region, access_key_id: Rails.application.credentials.access_key_id, secret_access_key: Rails.application.credentials.secret_access_key)

      bucket = Rails.application.credentials.aws_bucket

      time = Time.now.strftime("%F %H:%M:%S").to_s.tr('-', '')

      file_name = "lot_inventory_report_#{time.parameterize.underscore}"

      obj = amazon_s3.bucket(bucket).object("uploads/lot_inventory_report/#{file_name}.csv")

      obj.put(body: file_csv, acl: 'public-read', content_disposition: 'attachment', content_type: 'text/csv')

      url = obj.public_url
      
      return url

  end



  def self.check_for_errors(errors_hash,row_number,row,liquidation_item)

    
    error2 = ""
    flag = 1 
    error_found = false



    if !liquidation_item.present?

      error2 = "Liquidation tag number doesnt exist"
      error_found = true
      error_row = prepare_error_hash(row,row_number,error2)
      errors_hash[row_number] << error_row
    end


    if liquidation_item.present? && liquidation_item.status == LookupValue.where(code:Rails.application.credentials.liquidation_pending_lot_dispatch_status).first.original_code
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
    if !row["vendor_code"].present?
      error2 = "Vendor Code cannot be blank"
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

    if LiquidationOrder.find_by(order_number: row["order_number"]).present?
      error2 = "Order Number already exists"
      error_found = true
      error_row = prepare_error_hash(row, row_number, error2)
      errors_hash[row_number] << error_row 
    end
   

    return error_found , errors_hash



  end

  def self.prepare_error_hash(row, rownubmer, message)
    message = "Error In row number (#{rownubmer}) : " + message.to_s
    return {row: row, row_number: rownubmer, message: message}
  end

  def self.import_lots(liquidation_file_upload_id)


    errors_hash = Hash.new(nil)
    error_found = false
    liquidation_file_upload = LiquidationFileUpload.where("id = ?", liquidation_file_upload_id).first
    data = CSV.read(liquidation_file_upload.liquidation_file.path, {headers: true, encoding: "iso-8859-1:utf-8"})
    user = User.find(liquidation_file_upload.user_id)
  	#data = CSV.read(file.path, {headers: true, encoding: "iso-8859-1:utf-8"})
  	headers = data.headers
  	warehouse_order = {}
    new_liquidation_status = LookupValue.where(code:Rails.application.credentials.liquidation_status_inprogress_status).first
    begin
      Liquidation.transaction do 
      	data.each_with_index do |row, index|
          row_number = index + 1
          errors_hash.merge!(row_number => [])
          
          move_to_next = false      
          liquidation_item = Liquidation.find_by(tag_number: row["tag_number"])
          move_to_next , errors_hash = Liquidation.check_for_errors(errors_hash,row_number,row, liquidation_item) 




          if move_to_next
            error_found = true
          end

          next if move_to_next
         

      		if row["order_number"].present? && row["vendor_code"].present?
    	  		liquidation_order = LiquidationOrder.find_by(order_number: row["order_number"], vendor_code: row["vendor_code"])    	  		
    	  		if liquidation_order.present?    	  			
    	  			liquidation_order.update(order_amount:liquidation_order.order_amount.to_i + row["sales_price"].to_i)
    	  			warehouse_order = WarehouseOrder.find_by(orderable_id: liquidation_order.id , orderable_type: "LiquidationOrder")
    	  			warehouse_order.update(total_quantity: liquidation_order.order_amount)
    	  		else    	  			
    	  			liquidation_order = LiquidationOrder.create(order_number: row["order_number"], vendor_code: row["vendor_code"],order_amount: row["sales_price"].to_i)
    	  			warehouse_order = WarehouseOrder.create(orderable: liquidation_order,total_quantity: liquidation_order.order_amount, distribution_center_id:row["distribution_center_id"].to_i,status_id:LookupValue.find_by(code:Rails.application.credentials.order_status_warehouse_pending_pick).id,vendor_code:row["vendor_code"])
    	  		end
    	  		liquidation_item = Liquidation.find_by(tag_number: row["tag_number"])
    	  		liquidation_item.update(lot_name: row["lot_name"] , sales_price: row["sales_price"], liquidation_order_id: liquidation_order.id , status: new_liquidation_status.original_code , status_id: new_liquidation_status.id )
    	  		client_sku_master = liquidation_item.client_sku_master
    	  		client_category = client_sku_master.client_category
    	  		WarehouseOrderItem.create(warehouse_order_id:warehouse_order.id , inventory_id: liquidation_item.inventory_id , client_category_id: client_category.id , client_category_name: client_category.name , sku_master_code: client_sku_master.code ,item_description: liquidation_item.item_description , tag_number: liquidation_item.tag_number , serial_number: liquidation_item.inventory.serial_number , quantity: liquidation_item.sales_price , aisle_location: liquidation_item.aisle_location , status_id:LookupValue.find_by(code:Rails.application.credentials.order_status_warehouse_pending_pick).id, status: LookupValue.find_by(code:Rails.application.credentials.order_status_warehouse_pending_pick).original_code)
      		end
      		
      	end
      end
    ensure
      if error_found
        all_error_messages = errors_hash.values.flatten.collect do |h| h[:message].to_s end
        all_error_message_str = all_error_messages.join(',')
        
        
        liquidation_file_upload.update(status: "Halted", remarks: all_error_message_str) if liquidation_file_upload.present?
        return false
      else
        all_error_messages = errors_hash.values.flatten.collect do |h| h[:message].to_s end
        all_error_message_str = all_error_messages.join(',')
       
        liquidation_file_upload.update(status: "Completed") if liquidation_file_upload.present?
       
        return true
      end
    end
  end


  def self.import_inventories
  	Inventory.where(disposition: "Liquidation").each do |i|
      LiquidationOrder.create_record(i)  		
  	end
  end


  def self.create_record(inventory, path, user_id=nil, uploaded_user = nil, liquidation_pending_status = nil, client_sku_master_id = nil, create_history_record = true)
    if uploaded_user.present?
      user = uploaded_user
    elsif user_id.present?
      user = User.find_by_id(user_id)
    else
      user = inventory.user
    end

    liquidation_pending_status = LookupValue.where(code:Rails.application.credentials.liquidation_pending_status).first
    client_sku_master = ClientSkuMaster.where(code: inventory.sku_code).last
    client_sku_master_id = client_sku_master.id rescue nil

    liquidation = Liquidation.where("client_category_id = ? and sku_code = ? and grade = ? and mrp is not null and floor_price is not null", inventory.try(:client_category_id), inventory.sku_code, inventory.grade).last 
    mrp = liquidation.try(:mrp).present? ? liquidation.try(:mrp) : "2000"
    floor_price = if liquidation.try(:floor_price).present? 
      liquidation.try(:floor_price)
    elsif inventory.details['Benchmark Price'].present?
      inventory.details['Benchmark Price']
    else
      "1200"
    end
    liquidation_item = Liquidation.new( inventory_id: inventory.id, tag_number: inventory.tag_number , 
                                        item_description: inventory.item_description, sr_number: inventory.sr_number,serial_number: inventory.serial_number , serial_number_2:inventory.serial_number_2, toat_number: inventory.toat_number ,item_price: inventory.item_price, 
                                        client_tag_number: inventory.client_tag_number, client_id:inventory.client_id, aisle_location:inventory.aisle_location,
                                        location: inventory.details["destination_code"], grade: inventory.grade,  distribution_center_id: inventory.distribution_center_id, details: inventory.details, 
                                        status_id: liquidation_pending_status.try(:id), status: liquidation_pending_status.try(:original_code), sku_code: inventory.sku_code, brand: inventory.details["brand"],
                                        client_sku_master_id: client_sku_master_id , client_category_id: inventory.try(:client_category_id), mrp: mrp, floor_price: floor_price, item_price: mrp)
    liquidation_item.details["criticality"] = "Low"
    liquidation_item.details["path"] = path
    

    if liquidation_item.save
      LiquidationHistory.create(liquidation_id:liquidation_item.id , status_id: liquidation_pending_status.try(:id), status: liquidation_pending_status.try(:original_code), details: {"status_changed_by_user_id" => user&.id, "status_changed_by_user_name" => user&.full_name } ) if create_history_record
      liquidation_item
    end
  end

  def remarks
    if details["manual_remarks"].present?
      details["manual_remarks"]
    else
      inventory.remarks rescue 'NA'
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
    return true if self.inventory.liquidations.where.not(id: self.id).blank?
    return self.inventory.liquidations.where.not(id: self.id).where(is_active: true).blank?
  end

  def request_number
    liquidation_request.request_id rescue ''
  end

  def bench_mark_price
    inventory&.item_price.to_i
  end

  def post_lot_creation_cleanup user
    liquidation_request&.release_liquidation
    create_liquidation_history user
  end

  def create_liquidation_history user
    liquidation_histories.new({
      status_id: status_id,
      status: status,
      created_at: Time.now,
      updated_at: Time.now,
      details: {
        "status_changed_by_user_id" => user.id,
        "status_changed_by_user_name" => user.full_name
      }
    })
  end

  def release_from_current_lot user, new_status, params={}
    lot = LiquidationOrder.unscoped.find_by(id: self.liquidation_order_id)
    return unless lot
    lot.quantity = lot.quantity - 1 if lot.quantity.to_i >= 1
    lot.save
    self.is_active = true
    self.liquidation_order_id =  nil
    self.lot_name = nil
    self.status = new_status.original_code
    self.status_id = new_status.id
    self.details["reason_for_not_dispatch"] = params["reason"] if params["reason"].present?
    self.details["remark_for_not_dispatch"] = params["remark"] if params["remark"].present?
    self.details["removed_by_user_id"] = user.id
    self.details["removed_by_user_name"] = user.full_name
    if self.save
      update_details = user.present? ? { status_changed_by_user_id: user.id, status_changed_by_user_name: user.full_name } : {}
      LiquidationHistory.create(
        liquidation_id: id, status_id: status_id, status: status,
        created_at: Time.now, updated_at: Time.now, details: update_details
      )
    end
  end
end
