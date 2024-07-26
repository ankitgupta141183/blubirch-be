class InvoiceInventoryDetail < ApplicationRecord
	acts_as_paranoid
	belongs_to :invoice
	belongs_to :client_category
	belongs_to :client_sku_master

	include Filterable
	scope :filter_by_invoice_id, -> (invoice_id) { where("invoice_id = ?", "#{invoice_id}")}
	scope :filter_by_client_category_id, -> (client_category_id) { where("client_category_id = ?", "#{client_category_id}")}
	scope :filter_by_client_sku_master_id, -> (client_sku_master_id) { where("client_sku_master_id = ?", "#{client_sku_master_id}")}
	
	def self.import(file)
		CSV.foreach(file.path, headers: true) do |row|
			h = Hash.new
			details = Hash.new
			invoice = Invoice.where(invoice_number: row[0].try(:strip)).first			
			category_array = [row[1].try(:strip), row[2].try(:strip), row[3].try(:strip), row[4].try(:strip), row[5].try(:strip), row[6].try(:strip)]
      new_category = category_array.compact

			new_category.each_with_index do |individual_category, index|
        if index == 0
          last_category = ClientCategory.where(code: "l#{index+1}_#{individual_category.parameterize.underscore}").last
        else
          last_category = last_category.descendants.where(name: individual_category).last
        end
      end

      h["client_category_id"] = last_category.id
      sku_master_id = ClientSkuMaster.where(code: row[7].try(:strip)).last
      h["sku_master_id"] = sku_master_id
			invoice_inventory_detail = InvoiceInventoryDetail.where(invoice_id: invoice.id).last
			
			#headers = ["Code","Curr","Net Value","Plant","Material","Qty","Status Order","CN No","CN Date","Remark","Location","Months","Position No","Position Date"]
			
			if invoice_inventory_detail.present?
				invoice_inventory_detail.update_attributes(h)
			else
				invoice_inventory_detail = InvoiceInventoryDetail.new(h)
				invoice_inventory_detail.save
			end
		end
	end
	
end
