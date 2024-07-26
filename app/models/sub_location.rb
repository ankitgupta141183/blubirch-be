class SubLocation < ApplicationRecord
  belongs_to :distribution_center
  has_many :inventories
  
  validates_presence_of :code, :location_type
  validates_uniqueness_of :code, scope: [:distribution_center_id]
  
  enum location_type: { open: 1, closed: 2 }, _prefix: true

  before_destroy :check_pending_putaway_items

  def self.export_sublocation_sequence(distribution_center)
    file_csv = CSV.generate do |csv|
      csv << ["Sl. No", "Location", "Sub Location ID"]
      
      dc_code = distribution_center.code
      distribution_center.sub_locations.order(sequence: :asc).each_with_index do |sub_location, i|
        csv << [i+1, dc_code, sub_location.code]
      end
    end
    return file_csv
  end
  
  def self.update_sequence(file)
    ActiveRecord::Base.transaction do
      raise CustomErrors.new "Please upload file." if file.nil?
      data = CSV.read(file, :headers=>true)
    
      raise CustomErrors.new "Please upload for single Location." if data["Location"].uniq.count > 1
      location_code = data["Location"].uniq.first
      distribution_center = DistributionCenter.find_by_code(location_code)
      raise CustomErrors.new "Invalid Location." if distribution_center.blank?
      
      data.each_with_index do |row, i|
        sub_location = distribution_center.sub_locations.find_by(code: row["Sub Location ID"])
        raise CustomErrors.new "Invalid Sub Location ID - #{row["Sub Location ID"]}" if sub_location.blank?
        
        sub_location.update!(sequence: i+1)
      end
      distribution_center.update!(is_sorted: true)
    end
  end

  def self.export_sublocations(distribution_center)
    file_csv = CSV.generate do |csv|
      csv << ["Sl. No", "Location", "Sub Location ID", "Sub Location Name", "Sub Location Type", "Category", "Brand", "Grade", "Disposition", "Return Reason"]
      
      dc_code = distribution_center.code
      distribution_center.sub_locations.each_with_index do |sub_location, i|
        csv << [i+1, dc_code, sub_location.code, sub_location.name, sub_location.location_type, sub_location.category&.join(','), sub_location.brand&.join(','), sub_location.grade&.join(','), sub_location.disposition&.join(','), sub_location.return_reason&.join(',')]
      end
    end
    return file_csv
  end
  
  def self.import_sub_locations(file)
    ActiveRecord::Base.transaction do
      raise CustomErrors.new "Please upload file." if file.nil?
      data = CSV.read(file, :headers=>true)
      
      raise CustomErrors.new "Please upload for single Location." if data["Location"].uniq.count > 1
      location_code = data["Location"].uniq.first
      distribution_center = DistributionCenter.find_by_code(location_code)
      raise CustomErrors.new "Invalid Location." if distribution_center.blank?
      
      validate_rules(data)
      
      data.each do |row|
        next if row["Sub Location ID"].blank?
        
        sub_location = distribution_center.sub_locations.find_or_initialize_by(code: row["Sub Location ID"])
        
        sub_location.assign_attributes({name: row["Sub Location Name"], location_type: row["Sub Location Type"].downcase})
        sub_location.category = row["Category"].to_s.split(",").map(&:strip)
        sub_location.brand = row["Brand"].to_s.split(",").map(&:strip)
        sub_location.grade = row["Grade"].to_s.split(",").map(&:strip)
        sub_location.disposition = row["Disposition"].to_s.split(",").map(&:strip)
        sub_location.return_reason = row["Return Reason"].to_s.split(",").map(&:strip)
      
        # sub_location.ensure_inventory_rules unless sub_location.new_record?
        sub_location.save!
      end
    end
  end
  
  def self.validate_rules data
    rules_csv = CSV.read("#{Rails.root}/public/master_files/sub_location_rules.csv", :headers=>true)
    
    check_valid_rules(data["Category"], rules_csv['Category (L2)'], "Category")
    check_valid_rules(data["Brand"], rules_csv['Brand'], "Brand")
    check_valid_rules(data["Return Reason"], rules_csv['Return Reason'], "Return Reason")
    check_valid_rules(data["Grade"], rules_csv['Grade'], "Grade")
    check_valid_rules(data["Disposition"], rules_csv['Disposition'], "Disposition")
  end
  
  def self.check_valid_rules(data, rules_data, type)
    rules = rules_data.uniq.compact
    rules_type_data = data.compact.map{|i| i.to_s.split(",").map(&:strip) }.flatten.uniq
    raise CustomErrors.new "Invalid #{type} - #{(rules_type_data - rules).join(', ')}" if (rules_type_data - rules).present?
  end
  
  # def ensure_inventory_rules
  #   sl_inventories = self.inventories
  #   return if sl_inventories.blank?
  # 
  #   inv_categories = sl_inventories.pluck("details -> 'category_l2'").uniq
  #   inv_brands = sl_inventories.pluck("details -> 'brand'").uniq
  #   inv_grades = sl_inventories.pluck(:grade).uniq
  #   inv_dispositions = sl_inventories.pluck(:disposition).uniq
  #   inv_return_reasons = sl_inventories.pluck(:return_reason).uniq
  # end
  
  private
  
  def check_pending_putaway_items
    dc = self.distribution_center
    return if dc.sub_locations.count > 1
    raise CustomErrors.new "Can't delete sub location - #{self.code}. Pending Putaway items are there in this site location." if dc.inventories.not_inwarded.present?
  end
  
end
