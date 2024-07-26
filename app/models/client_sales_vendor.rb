class ClientSalesVendor < ApplicationRecord

	has_many :sales_vendor_locations

	def self.import_sales_vendors(file = nil,client_id = nil)
    if file.present? && client_id.present?
      sales_vendors = CSV.read(file.path, {headers: true, encoding: "iso-8859-1:utf-8"})
    else
    	file_name = 'public/internal_wms/sales_vendor_master.csv'
      file = File.new("#{Rails.root}/#{file_name}")      
      if (Client.all.size == 1)
        client_id = Client.first.id
      else
        raise "Client Information not present"
      end
      sales_vendors = CSV.read(file.path, {headers: true, encoding: "iso-8859-1:utf-8"})
    end

    sales_vendors.each do |row|
    	client_sale_vendor = self.includes(:vendor_site_mappings).where(vendor_code: row["Vendor Code"], vendor_name: row["Vendor Name"], vendor_type: row["Vendor Type"], client_id: client_id).first_or_create    	
    	client_sale_vendor.sales_vendor_locations.where(vendor_location: row["Location"]).first_or_create
    end

  end

end
