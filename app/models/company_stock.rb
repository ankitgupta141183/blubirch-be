class CompanyStock < ApplicationRecord
  acts_as_paranoid
  
  def self.import(file)
    begin
      i = 1
      ActiveRecord::Base.transaction do
        company_stocks = CSV.read(file.path, headers: true)
        company_stocks.each do |row|
          i = i+1
          h=Hash.new
          client_sku_master = ClientSkuMaster.where(code: row[1].try(:strip)).last
          h["client_id"] = Client.where(name: row[0].try(:strip)).last.try(:id)
          h["client_sku_master_id"] = client_sku_master.try(:id)
          h["serial_number"] = row[2].try(:strip)
          h["quantity"] = row[3].try(:strip)
          h["sold_quantity"] = row[4].try(:strip)
          h["mrp"] = row[5].try(:strip)
          h["sku_code"] = client_sku_master.description["sku"]
          h["tax_percentage"] = client_sku_master.description["tax_percentage"]
          h["item_description"] = client_sku_master.description["item_description"]
          h["brand"] = client_sku_master.description["brand"]
          h["model"] = client_sku_master.description["model"]
          h["hsn_code"] = client_sku_master.description["hsn_code"]
          h["location"] = client_sku_master.description["location"]
          h["category_id"] = client_sku_master.client_category_id
          h["category_name"] = ClientCategory.where(id: client_sku_master.client_category_id).last.try(:name)
          status = LookupValue.where(code: Rails.application.credentials.company_stock_inv_sts_ats).last
          h["status_id"] = status.id
          h["status"] = status.original_code
          company_stock = CompanyStock.new(h)
          company_stock.save
        end
      end
    rescue Exception => message
      return "Line Number #{i}:"+message.to_s
    end
  end

end
