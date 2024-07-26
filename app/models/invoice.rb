class Invoice < ApplicationRecord
	acts_as_paranoid
	belongs_to :distribution_center
	belongs_to :client
	has_many :invoice_inventory_details
	has_many :return_requests
	has_many :customer_return_reasons, through: :return_requests

	validates :invoice_number, presence: true, uniqueness: true


	include Filterable
	scope :filter_by_distribution_center_id, -> (distribution_center_id) { where("distribution_center_id = ?", "#{distribution_center_id}")}
	scope :filter_by_invoice_number, -> (invoice_number) { where("invoice_number ilike ?", "%#{invoice_number}%")}

	def self.import(file = nil)

		invoice_headers_hash = FileImportHeader.where(name: "Invoice")
		invoice_inventory_detail_headers_hash = FileImportHeader.where(name: "InvoiceInventoryDetail")

		file = File.new("#{Rails.root}/public/sample_files/invoices.csv") if file.nil?
		ActiveRecord::Base.transaction do
			CSV.foreach(file.path, headers: true) do |row|
				invoice = Invoice.where(invoice_number: row["Invoice Number"]).first
				distribution_center = DistributionCenter.where(name: row["Customer Name"].try(:strip)).first
				if (Client.all.size == 1)
          client = Client.first
        else
          client = Client.where(name: row["Client Name"].try(:strip)).first
        end

				if invoice.nil? && distribution_center.present?
					invoice_details_hash = {}
					invoice_headers_hash.where(is_hash: true).each do |invoice_header|
						invoice_details_hash.merge!({"#{invoice_header.headers.parameterize.underscore}": row[invoice_header.headers.to_s]})
					end
					invoice = Invoice.new(client_id: client.try(:id), distribution_center: distribution_center, invoice_number: row["Invoice Number"].try(:strip), details: invoice_details_hash)
				end

				if invoice.present? && distribution_center.present?
					inventory_details_hash = {}
					invoice_inventory_detail_headers_hash.where(is_hash: true).each do |invoice_inventory_detail_header_hash|
						inventory_details_hash.merge!({"#{invoice_inventory_detail_header_hash.headers.parameterize.underscore}" => row[invoice_inventory_detail_header_hash.headers.to_s]})
					end

					client_sku_master = ClientSkuMaster.where(code: row["Product Code/SKU"]).first
					if client_sku_master.present?
						invoice.invoice_inventory_details.build(quantity: row["Quantity"], return_quantity: 0, item_price: row["Item Price"].try(:strip), 
																										total_price: row["Total Price"].try(:strip), details: inventory_details_hash,
																										client_category_id: client_sku_master.client_category_id, client_sku_master_id: client_sku_master.id)
						invoice.save!
					end
				end
			end
		end
	end
end
