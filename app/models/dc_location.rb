class DcLocation < ApplicationRecord
  acts_as_paranoid
  belongs_to :distribution_center
  
  validates_presence_of :destination_code
  
  def self.import_dc_locations(file)
    raise CustomErrors.new "Please upload file." if file.blank?
    
    ActiveRecord::Base.transaction do
      data = CSV.read(file, :headers=>true)
      data.each do |row|
        raise CustomErrors.new "Either Pincode or DC Code should be present" if (row["Pincode"].blank? and row["DC Code"].blank?)
        if row["DC Code"].present?
          dc = DistributionCenter.find_by_code(row["DC Code"])
          raise CustomErrors.new "Invalid DC Code - #{row["DC Code"]}" if dc.blank?
        end
        distribution_center = DistributionCenter.find_by_code(row["Destination Code"])
        raise CustomErrors.new "Invalid Destination Code - #{row["Destination Code"]}" if distribution_center.blank?
        
        dc_location = DcLocation.find_or_initialize_by(pincode: row["Pincode"], dc_code: row["DC Code"])
        dc_location.destination_code = distribution_center.code
        dc_location.distribution_center = distribution_center
        dc_location.save!
      end
    end
  end
end
