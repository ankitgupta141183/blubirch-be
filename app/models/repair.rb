class Repair < ApplicationRecord
  acts_as_paranoid
  belongs_to :distribution_center
  belongs_to :inventory
  belongs_to :repair_order, optional: true

  # has_one :job_sheet
  has_many :repair_histories, dependent: :destroy
  has_many :repair_attachments, as: :attachable, dependent: :destroy
  # after_create :create_history
  # after_update :create_history, :if => Proc.new {|repair| repair.saved_change_to_status_id?}
  scope :dc_filter, ->(center_ids) { where(distribution_center_id: center_ids) }
  belongs_to :assigner, class_name: "User", foreign_key: :assigned_id, optional: true

  before_save :default_alert_level

  enum expected_revised_grade: { good: 1, very_good: 2, seal_packed: 3, open_box: 4, damaged: 5, mixed: 6, defective: 7, as_is: 8 }, _prefix: true
  enum repair_type: { location: 1, service_center: 2 }, _prefix: true
  enum repair_status: { pending_repair: 1, pending_dispatch_to_service_center: 2, pending_receipt_from_service_center: 3, repaired: 4, not_repaired: 5 }, _prefix: true
  enum tab_status: { pending_quotation: 1, pending_repair_approval: 2, pending_repair: 3, dispatch: 4, pending_disposition: 5 }, _prefix: true

  validates_presence_of :repair_status, :tab_status
  # validates_uniqueness_of :tag_number, allow_blank: true, :case_sensitive => false, unless: :check_active
  
  validates :expected_revised_grade, inclusion: { in: Repair.expected_revised_grades.keys }, if: Proc.new { self.expected_revised_grade.present? }
  validates :repair_type, inclusion: { in: Repair.repair_types.keys }, if: Proc.new { self.repair_type.present? }
  validates :repair_status, inclusion: { in: Repair.repair_statuses.keys }
  validates :tab_status, inclusion: { in: Repair.tab_statuses.keys }

  before_save do
    true if self.vendor_name.present?
    if self.vendor_code.blank? && self.inventory.vendor_code.present?
      self.vendor_code = self.inventory.vendor_code
    end
    if self.vendor_code.present? && self.vendor_name.blank?
      self.vendor_name = VendorMaster.find_by_vendor_code(self.vendor_code)&.vendor_name
    end
  end

  def self.import(file = nil)  	
    begin
    	
  	ActiveRecord::Base.transaction do

  		
  		if (!file.present?)
  		    file = File.new("#{Rails.root}/public/sample_files/repair_dataset.csv")
  		  end
  		  data = CSV.read(file.path, {headers: true, encoding: "iso-8859-1:utf-8"})
  		  headers = data.headers

  		  categories_size = headers.count { |x| x.include?("Category L") }
  		  category_ids = []
  		  detail_hash = Hash.new 
  		  precedence = {}
  		  condition = []
  		  definition = []
  		  persistent_defect_name = ""
  		      
  		      data.each_with_index do |row, index|

  		        # Code for fetching of catgory ids for uniq test andd grading rule starts

  		        categories_array = []
  		        (1..categories_size).each do |category_number|
  		          categories_array << row["Category L#{category_number}"]
  		        end
  		        
  		        if categories_array.present?
  		          last_category = nil
  		      categories_array.compact.each_with_index do |individual_category, index|
  		              if index == 0
  		                last_category = Category.where(code: "l#{index+1}_#{individual_category.parameterize.underscore}").last
  		              else
  		                last_category = last_category.descendants.where(name: individual_category).last
  		              end
  		            end
  		        client_category_id =  last_category.try(:id)            
  		      end

  		        
  		      inventory = Inventory.new(client_id:1,distribution_center_id:1,user_id:2,tag_number: row["Tag Number"], is_putaway_inwarded: false)


  		      row.each do |key,value|
  		        if ["Category L1","Category L2","Category L3","Category L4","Category L5","Category L6" , "Inventory ID","Tag Number" ,"Customer ID","Pending Putaway Disposition","Packaging Status",  "Item Condition", "Physical Status"].include?(key)

  		        else
  		          if key.parameterize.underscore.split('_').last == "date"
  		            detail_hash["#{key.parameterize.underscore}"] = DateTime.parse(value).to_s rescue nil
  		          else
  		            detail_hash["#{key.parameterize.underscore}"] = value
  		          end
  		          

  		        end
  		      end
  		      detail_hash["client_category_id"] = client_category_id
  		      inventory.details = detail_hash
  		      inventory.save
  		      end # data loop ends   

         
          
  	end # transaction ends
  		#master_file_upload.update(status: "Completed")
  	rescue
  		#master_file_upload.update(status: "Error")
  	end
  end

  def create_history(user_id=nil)
    if user_id.present?
      user = User.find_by_id(user_id) 
    else
      user = User.find_by_id(self.inventory.user_id) 
    end
    status = LookupValue.find(self.status_id)
    details_key = status.original_code.downcase.split(" ").join("_") + "_created_date"
    self.repair_histories.create(status: status.original_code, status_id: status_id, details: {details_key => Time.now.to_s, "status_changed_by_user_id" => user&.id, "status_changed_by_user_name" => user&.full_name } )
  end

  def update_document(data = {})
    attachment = self.repair_attachments.new({
      attachment_file: data[:file],
      attachment_type_id: self.status_id,
      attachment_type: self.status
    })
    attachment.save!
    message = "Document uploaded successfully."
    return message
  end

  def update_inventory_status(code)
    inventory = self.inventory
    lookup_key = LookupKey.find_by(code: "REPAIR_STATUS")
    bucket_status = lookup_key.lookup_values.find_by(original_code: code)
    raise CustomErrors.new "Invalid code." if bucket_status.blank?
    inventory.update_inventory_status!(bucket_status)
  end

  def pending_initiation_remark=(name)
    self.details.merge!({'pending_initiation_remark': name})  
  end

  def pending_quotation_remark=(name)
    self.details.merge!({'pending_quotation_remark': name}) 
  end
  
  def pending_approval_remark=(name)
    self.details.merge!({'pending_approval_remark': name}) 
  end

  def pending_repair_remark=(name)
    self.details.merge!({'pending_repair_remark': name})   
  end

  def pending_disposition_remark=(name)
    self.details.merge!({'pending_disposition_remark': name}) 
  end

  def details_disposition=(name)
    self.details.merge!({'disposition': name}) 
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

  def self.create_record(inventory, user_id)
    #status = LookupValue.where("original_code = ?", "Pending Repair Initiation").first
    status = LookupValue.where("original_code = ?", "Pending Quotation").first #& because it will be coming from Other disposition rule
    c_sku_master = ClientSkuMaster.where(client_category_id: inventory.client_category_id).first 
    ActiveRecord::Base.transaction do
      record                        = self.new
      record.client_sku_master_id   = c_sku_master.id if c_sku_master.present?
      record.sku_code               = inventory.sku_code
      record.distribution_center_id = inventory.distribution_center_id
      record.inventory_id           = inventory.id
      record.item_description       = inventory.item_description
      record.details                = inventory.details.merge!({serial_number: inventory.serial_number})
      record.details["criticality"] = "Low"
      record.tag_number             = inventory.tag_number
      record.status_id              = status.id
      record.status                 = status.original_code
      record.serial_number          = inventory.serial_number
      record.location               = inventory.details["destination_code"]
      record.grade                  = inventory.grade
      record.brand                  = inventory.details["brand"]
      record.client_id              = inventory.client_id
      record.client_category_id     = inventory.client_category_id
      record.client_tag_number      = inventory.client_tag_number
      record.serial_number          = inventory.serial_number
      record.serial_number_2        = inventory.serial_number_2
      record.toat_number            = inventory.toat_number
      record.item_price             = inventory.item_price
      record.aisle_location         = inventory.aisle_location
      record.tab_status             = :pending_quotation
      record.repair_status          = :pending_repair 
      record.save

      record.create_history(user_id)
    end
  end

  # def self.set_manual_disposition(vendor_return, user_id)
  #   vendor_return = vendor_return
  #   inventory = vendor_return.inventory
  #   status = LookupValue.find_by_code('repair_status_pending_repair') #& because it will be coming from Brand Call Log
  #   #status = LookupValue.find_by_code('repair_status_pending_repair_initiation')
  #   c_sku_master = ClientSkuMaster.where(client_category_id: inventory.client_category_id).first 
  #   ActiveRecord::Base.transaction do
  #     record                        = self.new
  #     record.client_sku_master_id   = c_sku_master.id if c_sku_master.present?
  #     record.sku_code               = inventory.sku_code
  #     record.distribution_center_id = inventory.distribution_center_id
  #     record.inventory_id           = inventory.id
  #     record.item_description       = inventory.item_description
  #     record.details                = inventory.details.merge!({serial_number: inventory.serial_number})
  #     record.tag_number             = inventory.tag_number
  #     record.status_id              = status.id
  #     record.status                 = status.original_code
  #     record.sr_number              = inventory.serial_number
  #     record.details["criticality"] = "Low"
  #     record.location               = inventory.details["destination_code"]
  #     record.grade                  = inventory.grade
  #     record.brand                  = inventory.details["brand"]
  #     record.client_id              = inventory.client_id
  #     record.client_category_id     = inventory.client_category_id
  #     record.client_tag_number      = inventory.client_tag_number
  #     record.serial_number          = inventory.serial_number
  #     record.serial_number_2        = inventory.serial_number_2
  #     record.toat_number            = inventory.toat_number
  #     record.item_price             = inventory.item_price
  #     record.aisle_location         = inventory.aisle_location
  #     record.rgp_number             = vendor_return.try(:inspection_rgp_number)
  #     record.email_date             = vendor_return.try(:brand_inspection_date)
  #     record.repair_location        = vendor_return.try(:inspection_replacement_location)
  #     record.tab_status             = :pending_repair
  #     record.repair_status          = :pending_repair
  #     if record.save
  #       record.create_history(user_id)
  #     end
  #   end
  # end

  def self.set_manual_disposition(inventory, user_id, repair_type = nil)
    #status = LookupValue.where("original_code = ?", "Pending Repair Initiation").first
    status = LookupValue.find_by_code('repair_status_pending_repair') #& because it will be coming from Brand Call Log
    c_sku_master = ClientSkuMaster.where(client_category_id: inventory.client_category_id).first 
    ActiveRecord::Base.transaction do
      record                        = self.new
      record.client_sku_master_id   = c_sku_master.id if c_sku_master.present?
      record.sku_code               = inventory.sku_code
      record.distribution_center_id = inventory.distribution_center_id
      record.inventory_id           = inventory.id
      record.item_description       = inventory.item_description
      record.details                = inventory.details.merge!({serial_number: inventory.serial_number})
      record.details["criticality"] = "Low"
      record.tag_number             = inventory.tag_number
      record.status_id              = status.id
      record.status                 = status.original_code
      record.serial_number          = inventory.serial_number
      record.location               = inventory.details["destination_code"]
      record.grade                  = inventory.grade
      record.brand                  = inventory.details["brand"]
      record.client_id              = inventory.client_id
      record.client_category_id     = inventory.client_category_id
      record.client_tag_number      = inventory.client_tag_number
      record.serial_number          = inventory.serial_number
      record.serial_number_2        = inventory.serial_number_2
      record.toat_number            = inventory.toat_number
      record.item_price             = inventory.item_price
      record.aisle_location         = inventory.aisle_location
      record.tab_status             = :pending_repair
      record.repair_status          = :pending_repair
      record.repair_type            = repair_type
      record.save

      record.create_history(user_id)
    end
  end

  def default_alert_level
    if status_changed? || status_id_changed?
      self.details['criticality'] = 'Low'
    end
  end

  def check_active
    if self.inventory.repairs.where.not(id: self.id).blank?
      return true 
    else
      return self.inventory.repairs.where.not(id: self.id).where(is_active: true).blank?
    end
  end
end
