require 'open-uri'
class DistributionCenter < ApplicationRecord

  has_logidze
  has_ancestry
  acts_as_paranoid
  include Filterable

  SITE_CATEGORY = {"A" => "Store", "D" => "DC", "R" => "RP Site", "I" => "Institutional Site", "E" => "Ecommerce Site", "W" => "Warehouse", "Z" => "Office", "C" => "Croma Care Center", "B" => "Repair Center"}

  validates :name, :code, presence: true

  scope :filter_by_name, -> (name) { where("name ilike ?", "%#{name}%")}
  scope :filter_by_parent_name, -> (parent_name) { where("parent.name ilike ?", "%#{parent_name}%")}
  scope :filter_by_parent_name, -> (parent_name) { where(ancestry: "#{DistributionCenter.where(name:"#{parent_name}").first.id}")}
  scope :filter_by_city, -> (city) { where("name ilike ?", "%#{city}%")}
  scope :filter_by_state, -> (state) { where("name ilike ?", "%#{state}%")}
  scope :filter_by_addr_line_1, -> (addr_line_1) { where("addr_line_1 ilike ?", "%#{addr_line_1}%")}
  scope :filter_by_addr_line_2, -> (addr_line_2) { where("addr_line_2 ilike ?", "%#{addr_line_2}%")}

  

  has_many :distribution_center_users
  has_many :users, through: :distribution_center_users

  has_many :distribution_center_clients
  has_many :clients, through: :distribution_center_clients
  has_many :master_file_uploads


  has_many :inventories
  has_many :packaging_boxes
  has_many :gate_passes
  has_many :liquidations
  has_many :warehouse_orders
  has_many :sub_locations
  has_many :put_requests

  has_one :channel
  has_many :invoices
  has_many :cost_labels
  has_many :vendor_distributions
  has_many :vendor_masters, through: :vendor_distributions
  has_many :saleables

  belongs_to :city, class_name: "LookupValue", foreign_key: :city_id, optional: true
  belongs_to :state, class_name: "LookupValue", foreign_key: :state_id, optional: true
  belongs_to :country, class_name: "LookupValue", foreign_key: :country_id, optional: true
  #after_create :create_vendor_master


  def address
    [self.address_line1, self.address_line2, self.address_line3, self.address_line4, self.try(:city).try(:original_code), self.try(:state).try(:original_code), self.try(:country).try(:original_code)].reject(&:blank?).join(", ")
  end

  def self.create_centers(master_file_upload_id, distribution_center_type)
    errors_hash = Hash.new(nil)
    error_found = false
    begin
      country_key = LookupKey.find_by_name('COUNTRY')
      state_key = LookupKey.find_by_name('STATE')
      city_key = LookupKey.find_by_name('CITY')

      master_file_upload = MasterFileUpload.where("id = ?", master_file_upload_id).first
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

      DistributionCenter.transaction do
        data.each do |row|
          i += 1
          row_number = (i+1)
          move_to_next = false
          errors_hash.merge!(row_number => [])
          parent = DistributionCenter.where(name: row['Parent']).last
          country = country_key.lookup_values.where(original_code: row['Country']).last
          state = state_key.lookup_values.where(original_code: row['State']).last
          city = city_key.lookup_values.where(original_code: row['City']).last

          if city.nil?
            if row["City"].present?
              city = city_key.lookup_values.create(original_code: row['City'])
            else
              error_found = true
              error_row = prepare_error_hash(row, row_number, "City is Mandatory for store")
              errors_hash[row_number] << error_row
              move_to_next = true
            end
          end

          if row["Name"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Name is Mandatory for store")
            errors_hash[row_number] << error_row
            move_to_next = true
          end
          if row["Code"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Code is Mandatory for store")
            errors_hash[row_number] << error_row
            move_to_next = true
          end
          if row["Country"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Country is Mandatory for store")
            errors_hash[row_number] << error_row
            move_to_next = true
          elsif country.blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Country doesn't match")
            errors_hash[row_number] << error_row
            move_to_next = true
          end
          if row["State"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "State is Mandatory for store")
            errors_hash[row_number] << error_row
            move_to_next = true
          elsif state.blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "State doesn't match")
            errors_hash[row_number] << error_row
            move_to_next = true
          end
          next if move_to_next

          distribution_center = DistributionCenter.new(name: row['Name'], distribution_center_type_id: distribution_center_type, address_line1: row['Address Line 1'], address_line2: row['Address Line 2'], address_line3: row['Address Line 3'], address_line4: row['Address Line 4'], city_id: city.id, state_id: state.id, country_id: country.id, code: row['Code'])
          distribution_center.save
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

  def create_vendor_master
    VendorMaster.import_store
  end

  def self.create_master_data(master_data_id)
    master_data = MasterDataInput.where("id = ?", master_data_id).first
    site_store_type = LookupValue.where("code = ?", "distribution_cnt_types_store")
    site_dc_type = LookupValue.where("code = ?", "distribution_cnt_types_dc")
    site_rp_type = LookupValue.where("code = ?", "distribution_cnt_types_rp_site")
    site_institutional_type = LookupValue.where("code = ?", "distribution_cnt_types_institutional_site")
    site_ecommerce_type = LookupValue.where("code = ?", "distribution_cnt_types_ecommerce_site")
    errors_hash = Hash.new(nil)
    error_found = false
    success_count = 0
    failed_count = 0
    if master_data.present?
      begin
        master_data.payload.each do |data|
          if data["site_category"] == "A"
            dc_type_id = site_store_type.try(:id)
          elsif data["site_category"] == "D"
            dc_type_id = site_dc_type.try(:id)
          elsif data["site_category"] == "R"
            dc_type_id = site_rp_type.try(:id)
          elsif data["site_category"] == "I"
            dc_type_id = site_institutional_type.try(:id)
          elsif data["site_category"] == "E"
            dc_type_id = site_ecommerce_type.try(:id)
          end
          distribution_center = DistributionCenter.where("code = ?", data["code"]).first
          if distribution_center.blank? 
            distribution_center = DistributionCenter.new(name: data['name'], distribution_center_type_id: dc_type_id, 
                                                         code: data['code'], site_category: data['site_category'])
            if distribution_center.save
              success_count = success_count + 1
            else
              failed_count = failed_count + 1
              errors_hash.merge!(data["code"] => [])
              error_found = true
              error_row = prepare_error_hash(distribution_center.errors.full_messages.join(","))
              errors_hash[data["code"]] << error_row
            end
          else
            if distribution_center.update(name: data['name'], distribution_center_type_id: dc_type_id, 
                                          code: data['code'], site_category: data['site_category'])
              success_count = success_count + 1
            else
              failed_count = failed_count + 1
              errors_hash.merge!(data["code"] => [])
              error_found = true
              error_row = prepare_error_hash(distribution_center.errors.full_messages.join(","))
              errors_hash[data["code"]] << error_row
            end
          end
        end
      rescue Exception => message
        master_data.update(status: "Failed", is_error: true, remarks: message.to_s, success_count: success_count, failed_count: failed_count) if master_data.present?
      else
        master_data.update(status: "Completed", is_error: false, success_count: success_count, failed_count: failed_count) if master_data.present?
      ensure
        if error_found
          master_data.update(status: "Completed", is_error: true, remarks: errors_hash, success_count: success_count, failed_count: failed_count) if master_data.present?
        end
      end
    end
  end

  def self.prepare_error_hash(message)
    return {message: message}
  end
  
  
  # Temp requirement to update existing inventories
  def export_uninwarded_items
    raise CustomErrors.new "Please define Sub Locations for this Location!" if self.sub_locations.blank?
    
    file_csv = CSV.generate do |csv|
      csv << ["Tag Number", "Location", "Disposition", "Sub Location ID"]
      
      inventories = self.inventories.opened.where(sub_location_id: nil)
      inventories.each do |inventory|
        csv << [inventory.tag_number, self.code, inventory.disposition, ""]
      end
    end
    
    # amazon_s3 = Aws::S3::Resource.new(region: Rails.application.credentials.aws_s3_region, access_key_id: Rails.application.credentials.access_key_id, secret_access_key: Rails.application.credentials.secret_access_key)
    # bucket = Rails.application.credentials.aws_bucket
    # time = Time.now.strftime("%F %H:%M:%S").to_s.tr('-', '')
    # 
    # file_name = "#{self.code}_#{time.parameterize.underscore}"
    # 
    # obj = amazon_s3.bucket(bucket).object("uploads/locations/#{file_name}.csv")
    # 
    # obj.put(body: file_csv, acl: 'public-read', content_disposition: 'attachment', content_type: 'text/csv')
    # 
    # url = obj.public_url
    # 
    # puts url
    # return url
    return file_csv
  end
  
  def self.update_sub_locations(file)
    raise CustomErrors.new "Please upload file." if file.nil?
    
    ActiveRecord::Base.transaction do
      data = CSV.read(file, :headers=>true)
      
      raise CustomErrors.new "Please upload for single Location." if data["Location"].uniq.count > 1
      location_code = data["Location"].uniq.first
      distribution_center = DistributionCenter.find_by_code(location_code)
      raise CustomErrors.new "Invalid Location." if distribution_center.blank?
      
      data.each do |row|
        next if (row["Tag Number"].blank? or row["Sub Location ID"].blank?)
        
        inventory = Inventory.find_by(tag_number: row["Tag Number"])
        raise CustomErrors.new "Invalid Tag Number - #{row["Tag Number"]}" if inventory.blank?
        raise CustomErrors.new "Request has been created for this item #{row["Tag Number"]}" if inventory.put_request_created?
        raise CustomErrors.new "Item #{row["Tag Number"]} is already inwarded!" if inventory.is_putaway_inwarded?

        sub_location = distribution_center.sub_locations.find_by_code(row["Sub Location ID"])
        raise CustomErrors.new "Invalid Sub Location #{row["Sub Location ID"]} for the Tag Number #{row["Tag Number"]}" if sub_location.blank?
        
        inventory.update!(sub_location_id: sub_location.id, is_putaway_inwarded: true)
      end
    end
  end

end
