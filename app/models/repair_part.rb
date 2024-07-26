class RepairPart < ApplicationRecord
  
  acts_as_paranoid
  scope :active, -> { where( is_active: true ) }

  def self.import(param_file)
    if param_file.present?
      data = CSV.read(param_file.path, {headers: true, encoding: "iso-8859-1:utf-8"})
    else
      file = File.new("#{Rails.root}/public/master_files/repair_parts.csv")
      data = CSV.read(file.path, {headers: true, encoding: "iso-8859-1:utf-8"})
    end
    headers = data.headers
    data.each do |row|
      ActiveRecord::Base.transaction do
        repair_part = RepairPart.new
        repair_part.hsn_code = row[1]
        repair_part.name = row[2]
        repair_part.price = row[3]
        repair_part.save
      end
    end
  end

end
