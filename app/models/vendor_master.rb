class VendorMaster < ApplicationRecord

  include VendorMasterSearchable
  include Filterable

  acts_as_paranoid

  has_many :vendor_quotation_links
  has_many :quotations
  has_many :vendor_distributions
  has_many :distribution_centers, through: :vendor_distributions
  has_many :master_file_uploads
  has_many :vendor_rate_cards
  has_many :vendor_types

  validates :vendor_code, :vendor_name, presence: true, :uniqueness => true
  validates :vendor_phone, :uniqueness => true, :numericality => true, :length => { :minimum => 10, :maximum => 15 }, if: Proc.new { self.vendor_phone.present? }
  validates :vendor_email, format: { with: URI::MailTo::EMAIL_REGEXP }, if: Proc.new { self.vendor_email.present? } 


  def self.import(master_file_upload_id=nil)
    errors_hash = Hash.new(nil)
    error_found = false
    begin
      master_file_upload = MasterFileUpload.where("id = ?", master_file_upload_id).first
      i = 0
      if master_file_upload.present?
        temp_file = open(master_file_upload.master_file.url)
        file = File.new(temp_file)
        data = CSV.read(file.path, {headers: true, encoding: "iso-8859-1:utf-8"})
        user = User.find(master_file_upload.user_id)
      else
        file = File.new("#{Rails.root}/public/master_files/Liquidation Vendor.csv")
        data = CSV.read(file.path, {headers: true, encoding: "iso-8859-1:utf-8"})
        user = User.last
      end

      VendorMaster.transaction do
        headers = data.headers
        
        data.each_with_index do |row, index|
          i += 1
          row_number = (i+1)
          move_to_next = false
          errors_hash.merge!(row_number => [])

          if row["Vendor Code"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Vendor Code is Mandatory for Vendor Master")
            errors_hash[row_number] << error_row
            move_to_next = true
          end

          if row["Vendor Type"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Vendor Type is Mandatory for Vendor Master")
            errors_hash[row_number] << error_row
            move_to_next = true
          else
            row["Vendor Type"].split('/').each do |type|
              unless LookupValue.find_by(code: "vendor_type_#{type.strip.gsub(/[^A-Za-z]/, '_').downcase}")
                error_found = true
                error_row = prepare_error_hash(row, row_number, "Vendor Type #{type} doesn't match")
                errors_hash[row_number] << error_row
                move_to_next = true
              end
            end
          end

          if row["Vendor Name"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Vendor Name is Mandatory for Vendor Master")
            errors_hash[row_number] << error_row
            move_to_next = true
          end

          if row["Distribution Center Code"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Distribution Center Code is Mandatory for Vendor Master")
            errors_hash[row_number] << error_row
            move_to_next = true
          end

          next if move_to_next
          vm = VendorMaster.find_or_initialize_by(vendor_code: row["Vendor Code"])
          vm.update(vendor_code: row["Vendor Code"], vendor_name: row["Vendor Name"], vendor_address: row["Vendor Address"], vendor_city: row["Vendor City"], vendor_state: row["Vendor State"], vendor_pin: row["Vendor Pin"], vendor_email: row["Vendor Email"], vendor_phone: row["Vendor Phone"], brand: row["Brand"], e_waste_certificate: row["E-waste Certificate"] || vm.e_waste_certificate)
          row["Vendor Type"].split('/').each do |type|
            lookup = LookupValue.find_by(code: "vendor_type_#{type.strip.gsub(/[^A-Za-z]/, '_').downcase}")
            vm.assign_vendor_type(lookup)
          end
          distribution_centers = DistributionCenter.where(code: row['Distribution Center Code'].gsub(' ', '').split(','))
          distribution_centers.each do |dc|
            vm.vendor_distributions.create(distribution_center_id: dc.id) unless vm.distribution_centers.pluck(:distribution_center_id).include?(dc.id)
          end
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

  #VendorMaster.vendor_name_by_code
  def self.vendor_name_by_code
    Rails.cache.fetch("cache_vendor_name_by_code_redis", expires_in: 1.hour) do
      vendor_hash = {}
      VendorMaster.all.collect{|d| vendor_hash[d.vendor_code] = d.vendor_name}
      vendor_hash
    end
  end

  #VendorMaster.get_vendor_master_data(user)
  def self.get_vendor_master_data(user)
    Rails.cache.fetch("cache_vendor_master_data_redis", expires_in: 1.hour) do
      VendorMaster.joins(:vendor_types).where.not(vendor_code: user.distribution_centers.pluck(:code)).distinct if user.present?
    end
  end

  #& VendorMaster.generate_code
  def self.generate_code
    vendor_code = ""
    loop do
      vendor_code = rand(1000000000..9999999999)
      break if VendorMaster.find_by_vendor_code(vendor_code).blank?
    end
    return vendor_code
  end

  def self.prepare_error_hash(row, rownubmer, message)
    message = "Error In row number (#{rownubmer}) : " + message.to_s
    return {row: row, row_number: rownubmer, message: message}
  end

  def self.import_store

    lookup_values = LookupValue.where(code: ['distribution_cnt_types_store', 'distribution_cnt_types_warehouse'])

    DistributionCenter.where(distribution_center_type_id: lookup_values.pluck(:id)).each do |dc|
      begin

        ActiveRecord::Base.transaction do
          vr = VendorMaster.where(vendor_code: dc.code)
          if vr.blank?
            lookup = LookupValue.find_by_original_code('Internal Vendor')
            array = dc.name.split('-')
            dc_name = array.first(array.size - 1).join(' ')
            vm = VendorMaster.create(vendor_code: dc.code, vendor_name: dc_name, vendor_city: dc.city.original_code, vendor_state: dc.state.original_code, vendor_address: dc.address_line1)
            vm.assign_vendor_type(lookup)
          end
        end
      rescue ActiveRecord::StatementInvalid => e
        puts "=======================#{e.message.inspect}============================"
      end
    end
  end

  def self.create_master_data(master_data_id)
    master_data = MasterDataInput.where("id = ?", master_data_id).first
    errors_hash = Hash.new(nil)
    error_found = false
    success_count = 0
    failed_count = 0
    lookup = LookupValue.where("code = ?", "vendor_type_external_vendor").first
    if master_data.present?
      begin
        master_data.payload.each do |data|
          vendor_master = VendorMaster.where("vendor_code = ?", data["code"]).first
          if vendor_master.blank?
            vendor_master = VendorMaster.new(vendor_code: data["code"], vendor_name: data["name"])
            if vendor_master.save
              vendor_master.assign_vendor_type(lookup)
              success_count = success_count + 1
            else
              failed_count = failed_count + 1
              errors_hash.merge!(data["code"] => [])
              error_found = true
              error_row = prepare_error_hash(vendor_master.errors.full_messages.join(","))
              errors_hash[data["code"]] << error_row
            end
          else
            if vendor_master.update(vendor_code: data["code"], vendor_name: data["name"])
              vendor_master.assign_vendor_type(lookup)
              success_count = success_count + 1
            else
              failed_count = failed_count + 1
              errors_hash.merge!(data["code"] => [])
              error_found = true
              error_row = prepare_error_hash(vendor_master.errors.full_messages.join(","))
              errors_hash[data["code"]] << error_row
            end
          end
        end
      rescue Exception => message
        master_data.update(status: "Failed", remarks: message.to_s, is_error: true, success_count: success_count, failed_count: failed_count) if master_data.present? 
      else
        master_data.update(status: "Completed", is_error: false, remarks: errors_hash, success_count: success_count, failed_count: failed_count) if master_data.present?
      ensure
        if error_found
          master_data.update(status: "Failed", remarks: errors_hash, is_error: true, success_count: success_count, failed_count: failed_count) if master_data.present?
        end
      end
    end
  end

  def self.prepare_error_hash(message)
    return {message: message}
  end

  def assign_vendor_type(lookup)
    if (lookup.original_code == "Brand Call-Log" && self.vendor_types.blank?) || (lookup.original_code != "Brand Call-Log" && self.vendor_types.pluck(:vendor_type_id).exclude?(lookup.id) && self.vendor_types.pluck(:vendor_type).exclude?("Brand Call-Log"))
      self.vendor_types.create(vendor_type_id: lookup.id, vendor_type: lookup.original_code)
    end
  end
end
