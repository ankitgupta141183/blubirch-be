class ClientSkuMaster < ApplicationRecord

  has_ancestry
  belongs_to :client_category

  has_one :liquidation

  has_many :sku_eans
  has_many :bom_mappings
  has_many :bom_articles, through: :bom_mappings
  has_many :order_management_items, as: :inventory

  validates :code, :sku_description, :item_type,  presence: true
  acts_as_paranoid
  

  # filter logic starts
  include Filterable
  scope :filter_by_code, -> (code) { where("code ilike ?", "%#{code}%")}
  scope :filter_by_brand, -> (brand) { where("brand ilike ?", "%#{brand}%")}
  scope :filter_by_client_category_id, -> (client_category_id) { where("client_category_id = ?", "#{client_category_id}")}
  scope :filter_by_item_description, -> (item_description) { where("description ->> 'item_description' ilike ?", "%#{item_description}%")}
  # filter logic ends

  def self.import(file=nil)
    begin
      i = 1
      ActiveRecord::Base.transaction do
        file = File.new("#{Rails.root}/public/master_files/UPDATED SKU MASTER1.csv")
        sku_masters = CSV.read(file.path, headers: true)
        sku_masters.each do |row|
          i = i+1
          category_array = [row[0].try(:strip), row[1].try(:strip), row[2].try(:strip), row[3].try(:strip), row[4].try(:strip), row[5].try(:strip)]
          new_category = category_array.compact
          last_category = nil
          new_category.each_with_index do |individual_category, index|
            if index == 0
              last_category = ClientCategory.where(code: "l#{index+1}_#{individual_category.parameterize.underscore}").last
            else
              last_category = last_category.descendants.where(name: individual_category).last
            end
          end
          category_attributes = []
          last_category.attrs.each do |cat_att|
            category_attributes << cat_att[:name]
          end
          h=Hash.new
          csm_description = {}
          row.to_hash.each do |k,v|
            if category_attributes.include?(k)
              csm_description[k] = v
            end
          end
          h["description"] = csm_description
          h["client_category_id"] = last_category.id
          h["code"] = row[6].try(:strip)
          h["own_label"] = row[9].try(:strip) if row[9].present?
          sku_master = ClientSkuMaster.where(code: row[6].try(:strip)).last
          if sku_master.present?
            sku_master.update_attributes(h)
          else
            sku_master = ClientSkuMaster.new(h)
            sku_master.save
          end
        end
      end
    rescue Exception => message
      return "Line Number #{i}:"+message.to_s
    end
  end

  def self.import_client_sku_masters(master_file_upload_id=nil)
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
        file = File.new("#{Rails.root}/public/sample_files/SKU Master-18-02-22.csv")
        data = CSV.read(file.path, {headers: true, encoding: "iso-8859-1:utf-8"})
        user = User.last
      end

      ClientSkuMaster.transaction do

        headers = data.headers

        categories_size = headers.count { |x| x.include?("Category L") }
               
        data.each_with_index do |row, index|
          i += 1
          row_number = (i+1)
          move_to_next = false
          errors_hash.merge!(row_number => [])

          categories_array = []
          (1..categories_size).each do |category_number|
            categories_array << row["Category L#{category_number}"]
          end
          
          if (Client.all.size == 1)
            client_id = Client.first.id
          else
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Client Information not present")
            errors_hash[row_number] << error_row
            move_to_next = true
          end

          if row["SKU"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "SKU is Mandatory for Sku Master")
            errors_hash[row_number] << error_row
            move_to_next = true
          elsif row["SKU"].count("a-zA-Z") > 0
            error_found = true
            error_row = prepare_error_hash(row, row_number, "SKU must be a number")
            errors_hash[row_number] << error_row
            move_to_next = true
          end

          if row["Category L1"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Category L1 is Mandatory for Sku Master")
            errors_hash[row_number] << error_row
            move_to_next = true
          end

          if row["Category L2"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Category L2 is Mandatory for Sku Master")
            errors_hash[row_number] << error_row
            move_to_next = true
          end

          if row["Category L3"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Category L3 is Mandatory for Sku Master")
            errors_hash[row_number] << error_row
            move_to_next = true
          end

          if row["SKU Description"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "SKU Description is Mandatory for Sku Master")
            errors_hash[row_number] << error_row
            move_to_next = true
          end

          if row["Brand"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Brand is Mandatory for Sku Master")
            errors_hash[row_number] << error_row
            move_to_next = true
          end

          if row["EAN"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "EAN is Mandatory for Sku Master")
            errors_hash[row_number] << error_row
            move_to_next = true
          end

          if row["Own Label"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Own Label is Mandatory for Sku Master")
            errors_hash[row_number] << error_row
            move_to_next = true
          elsif !(['true', 'false'].include?(row["Own Label"]))
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Own Label must be true or false only")
            errors_hash[row_number] << error_row
            move_to_next = true
          end

          # if row["UPC"].blank?
          #   error_found = true
          #   error_row = prepare_error_hash(row, row_number, "UPC is Mandatory for Sku Master")
          #   errors_hash[row_number] << error_row
          #   move_to_next = true
          # end
          
          next if move_to_next

          if categories_array.present?
            last_category = nil
            categories_array.compact.each_with_index do |individual_category, index|
              if index == 0
                last_category = ClientCategory.where(client_id: client_id, code: "l#{index+1}_#{individual_category.parameterize.underscore}").last
              else
                last_category = last_category.descendants.where(code: "#{last_category.name.parameterize.underscore}_l#{index+1}_#{individual_category.parameterize.underscore}").last if last_category.present?
              end
            end
            if last_category.present?
              client_sku_master = ClientSkuMaster.where(code: row["SKU"], client_category_id: last_category.id).first
              if row['Images'].present?
                image_hash = {}
                row['Images'].split(',').each do |side_with_url|
                  side, url = side_with_url.split('::')
                  amazon_s3 = Aws::S3::Resource.new(region: Rails.application.credentials.aws_s3_region, access_key_id: Rails.application.credentials.access_key_id, secret_access_key: Rails.application.credentials.secret_access_key)
                  bucket = Rails.application.credentials.aws_bucket
                  file = open(url)
                  file_name = File.basename(file, ".*")
                  obj = amazon_s3.bucket(bucket).object("stn/#{client_sku_master.code}/#{side}/#{file_name}.png")
                  obj.put(body: file, acl: 'public-read', content_type: 'image/png')
                  new_url = obj.public_url
                  image_hash[side] = new_url
                end
              end
              if client_sku_master.present?
                images = image_hash.present? ? [image_hash] : client_sku_master.images
                client_sku_master.update(ean: row["EAN"], upc: row["UPC"], sku_description: row["SKU Description"], item_type: row["Category L3"], mrp: row["MRP"], brand: row["Brand"], description: {"category_l1" => row["Category L1"], "category_l2" => row["Category L2"], "category_l3" => row["Category L3"]}, own_label: (row["Own Label"].try(:to_s) == "true" ? true : false), images: images)
              else
                images = image_hash.present? ? [image_hash] : []
                ClientSkuMaster.create(code: row["SKU"], ean: row["EAN"], upc: row["UPC"], sku_description: row["SKU Description"], item_type: row["Category L3"], mrp: row["MRP"], brand: row["Brand"],client_category_id: last_category.id, own_label: (row["Own Label"].try(:to_s) == "true" ? true : false), description: {"category_l1" => row["Category L1"], "category_l2" => row["Category L2"], "category_l3" => row["Category L3"]}, images: images)
              end
            end           
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

  def self.create_master_data(master_data_id)
    master_data = MasterDataInput.where("id = ?", master_data_id).first
    errors_hash = Hash.new(nil)
    error_found = false
    success_count = 0
    failed_count = 0
    if master_data.present?
      if (Client.all.size == 1)
        client_id = Client.first.id
      else
        raise "Client Information not present"
      end

      begin
        master_data.payload.each_with_index do |row, index|
          categories_array = []
          categories_code = []
          (1..3).each do |category_number|
            categories_array << row["category_l#{category_number}"]
            categories_code << row["category_code_l#{category_number}"]            
          end
          if categories_array.compact.reject(&:blank?).present?
            last_category = nil
            if categories_array.compact.reject(&:blank?).size == 3
              categories_array = [categories_array[1], categories_array[2], categories_array[0]]
              categories_code = [categories_code[1], categories_code[2], categories_code[0]]
            elsif categories_array[1].present? && categories_array[2].present?
              categories_array = [categories_array[1], categories_array[2]]
              categories_code = [categories_code[1], categories_code[2]]
            elsif categories_array[0].present?
              categories_array = [categories_array[0]]
              categories_code = [categories_code[0]]
            end
            categories_array.compact.reject(&:blank?).each_with_index do |individual_category, index|
              if index == 0
                last_category = ClientCategory.where(client_id: client_id, code: "l#{index+1}_#{individual_category.parameterize.underscore}").last
                if last_category.nil?
                  last_category = ClientCategory.create(cat_code: categories_code[index], name: individual_category, client_id: client_id, parent: nil, attrs: [], code: "l#{index+1}_#{individual_category.parameterize.underscore}")                
                end
              else
                parent_category = ClientCategory.where("client_id = ? and code = ?", client_id, "l#{index}_#{last_category.name.parameterize.underscore}").first if index == 1
                if index != 1
                  pre_parent_name = categories_array.compact.reject(&:blank?)[index-2]
                  parent_category = ClientCategory.where("code = ?", "#{pre_parent_name.parameterize.underscore}_l#{index}_#{last_category.name.parameterize.underscore}").first
                end
                last_category = ClientCategory.where(client_id: client_id, code: "#{parent_category.name.parameterize.underscore}_l#{index+1}_#{individual_category.parameterize.underscore}").last 
                if last_category.nil?
                  last_category = ClientCategory.create(cat_code: categories_code[index], name: individual_category, client_id: client_id, parent: parent_category, attrs: [], code: "#{parent_category.name.parameterize.underscore}_l#{index+1}_#{individual_category.parameterize.underscore}")
                end
              end
            end
            if last_category.present?
              client_sku_master = ClientSkuMaster.where(code: row["sku"], client_category_id: last_category.id).first
              if client_sku_master.present?
                is_own_label = row["brand"].try(:downcase).present? ? (row["brand"].try(:downcase).split(' ').include?('croma') rescue false) : false
                if client_sku_master.update(sku_description: row["sku_description"], item_type: categories_array.last, 
                                         mrp: row["mrp"], brand: row["brand"], imei_flag: row["imei_flag"],
                                         description: {"category_l1" => row["category_l2"], "category_l2" => row["category_l3"], "category_l3" => row["category_l1"], "category_code_l1" => row["category_code_l2"], "category_code_l2" => row["category_code_l3"], "category_code_l3" => row["category_code_l1"]}, 
                                         own_label: is_own_label, scannable_flag: row["scannable_flag"], 
                                         category_code: categories_code.compact.reject(&:blank?).last, sku_component: row["sku_component"].reject { |c| c.empty? })
                  success_count = success_count + 1
                  if row["ean"].reject { |c| c.empty? }.present?
                    row["ean"].reject { |c| c.empty? }.each do |ean|
                      sku_ean = client_sku_master.sku_eans.build(ean: ean)
                      sku_ean.save
                    end
                  end
                else
                  failed_count = failed_count + 1
                  errors_hash.merge!(row["sku"] => [])
                  error_found = true
                  error_row = prepare_error_message(client_sku_master.errors.full_messages.join(","))
                  errors_hash[row["sku"]] << error_row
                end
              else
                is_own_label = row["brand"].try(:downcase).present? ? (row["brand"].try(:downcase).split(' ').include?('croma') rescue false) : false
                client_sku_master = ClientSkuMaster.new(code: row["sku"], client_category_id: last_category.id, sku_description: row["sku_description"], item_type: categories_array.last, 
                                         mrp: row["mrp"], brand: row["brand"], imei_flag: row["imei_flag"],
                                         description: {"category_l1" => row["category_l2"], "category_l2" => row["category_l3"], "category_l3" => row["category_l1"], "category_code_l1" => row["category_code_l2"], "category_code_l2" => row["category_code_l3"], "category_code_l3" => row["category_code_l1"]}, 
                                         own_label: is_own_label, scannable_flag: row["scannable_flag"], 
                                         category_code: categories_code.compact.reject(&:blank?).last, sku_component: row["sku_component"].reject { |c| c.empty? })
                if client_sku_master.save
                  success_count = success_count + 1
                  if row["ean"].reject { |c| c.empty? }.present?
                    row["ean"].reject { |c| c.empty? }.each do |ean|
                      sku_ean = client_sku_master.sku_eans.build(ean: ean)
                      sku_ean.save
                    end
                  end
                  # Associate SKU Component
                  if client_sku_master.sku_component.present?
                    child_client_sku_masters = ClientSkuMaster.where("code in (?)", client_sku_master.sku_component)
                    child_client_sku_masters.update_all(ancestry: client_sku_master.to_s) if child_client_sku_masters.present?
                  end                    
                else
                  failed_count = failed_count + 1
                  errors_hash.merge!(row["sku"] => [])
                  error_found = true
                  error_row = prepare_error_message(client_sku_master.errors.full_messages.join(","))
                  errors_hash[row["sku"]] << error_row
                end
              end
            end # if last_category.present?
          else
            failed_count = failed_count + 1
            errors_hash.merge!(row["sku"] => [])
            error_found = true
            error_row = prepare_error_message("Category Structure is not present")
            errors_hash[row["sku"]] << error_row
          end # if categories_array.compact.reject(&:blank?).present?
        end # master_data.payload loop
      rescue Exception => message
        master_data.update(status: "Failed", remarks: message.to_s, is_error: true, success_count: success_count, failed_count: failed_count) if master_data.present? 
      else
        master_data.update(status: "Completed", is_error: false, remarks: errors_hash, success_count: success_count, failed_count: failed_count) if master_data.present?
      ensure
        if error_found
          master_data.update(status: "Completed", remarks: errors_hash, is_error: true, success_count: success_count, failed_count: failed_count) if master_data.present?
        end
      end # begin rescue block
    end
  end


  def self.prepare_error_message(message)
    return {message: message}
  end
  
  def self.prepare_error_hash(row, rownubmer, message)
    message = "Error In row number (#{rownubmer}) : " + message.to_s
    return {row: row, row_number: rownubmer, message: message}
  end
  
  # data = [{sku_code: "B123", quantity: 1}, {sku_code: "B123", quantity: 1}]
  def create_bom_mappings(data)
    data.each do |row|
      bom_article = ClientSkuMaster.find_by(code: row[:sku_code])
      
      bom_mapping = bom_mappings.find_or_initialize_by(bom_article_id: bom_article.id, sku_code: row[:sku_code])
      bom_mapping.quantity = row[:quantity]
      bom_mapping.uom = bom_article.uom
      bom_mapping.uom_id = bom_article.uom_id
      bom_mapping.save!
    end
  end

end
