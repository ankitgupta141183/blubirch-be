class ClientProcurementVendor < ApplicationRecord

	has_many :vendor_site_mappings, as: :vendor_mappable
  has_many :distribution_centers, through: :vendor_site_mappings
  
  validates :vendor_code, :vendor_name, :vendor_type, presence: true


  def self.import_procurement_vendors(file = nil,client_id = nil)
    if file.present? && client_id.present?
      procurement_vendors = CSV.read(file.path, {headers: true, encoding: "iso-8859-1:utf-8"})
    else
    	file_name = 'public/internal_wms/procurement_vendor_master.csv'
      file = File.new("#{Rails.root}/#{file_name}")      
      if (Client.all.size == 1)
        client_id = Client.first.id
      else
        raise "Client Information not present"
      end
      procurement_vendors = CSV.read(file.path, {headers: true, encoding: "iso-8859-1:utf-8"})
    end

    procurement_vendors.each do |row|
    	client_procurement_vendor = self.includes(:vendor_site_mappings).where(vendor_code: row["Vendor Code"], vendor_name: row["Vendor Name"], vendor_type: row["Vendor Type"], client_id: client_id).first_or_create    	
    	client_procurement_vendor.vendor_site_mappings.where(vendor_location: row["Location"]).first_or_create
    end

  end

end
