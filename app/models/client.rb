class Client < ApplicationRecord
  
  has_logidze
  acts_as_paranoid

	has_many :distribution_center_clients
  has_many :distribution_centers, through: :distribution_center_clients
  	has_many :liquidations
  
	has_many :client_attribute_masters
	has_many :client_categories
	has_many :master_file_uploads

	belongs_to :city, class_name: "LookupValue", foreign_key: :city_id
	belongs_to :state, class_name: "LookupValue", foreign_key: :state_id
	belongs_to :country, class_name: "LookupValue", foreign_key: :country_id

  validates :name, :domain_name, presence: true

	include Filterable
  scope :filter_by_name, -> (name) { where("name ilike ?", "%#{name}%")}
  scope :filter_by_domain_name, -> (domain_name) { where("domain_name ilike ?", "%#{domain_name}%")}

  def address
  	[self.address_line1, self.address_line2, self.address_line3, self.address_line4, self.try(:city).try(:original_code), self.try(:state).try(:original_code), self.try(:country).try(:original_code)].reject(&:blank?).join(", ")
  end

  def self.bootstrap_data
  	
  	#Import Lookup Keys
		LookupKey.import

		#Import Lookup Keys
		LookupValue.import

		# # Creation of Distribution Center
		# DistributionCenter.find_or_create_by!(name: "A066") do |distribution_center|
		#   distribution_center.address_line1 = "2/1, 27th Cross"
		#   distribution_center.address_line2 = "7th Main Rd"
		#   distribution_center.address_line3 = "Behind Krishna Grand Hotel"
		#   distribution_center.address_line4 = "Banashankari Stage II"
		#   distribution_center.details = {"vendor_code" => "A066"}
		#   country = LookupValue.where("original_code = ?", "India").first
		#   state = LookupValue.where("original_code = ?", "Karnataka").first
		#   city = LookupValue.where("original_code = ?", "Bangalore").first
		#   distribution_center.distribution_center_type_id = LookupValue.where("code = ?", Rails.application.credentials.distribution_center_types_store).first.try(:id)
		#   distribution_center.country_id = country.id
		#   distribution_center.state_id = state.id
		#   distribution_center.city_id = city.id
		#   distribution_center.code = "A066"
		# end

		# DistributionCenter.find_or_create_by!(name: "RP03") do |distribution_center|
		#   distribution_center.address_line1 = "2/1, 27th Cross"
		#   distribution_center.address_line2 = "7th Main Rd"
		#   distribution_center.address_line3 = "Behind Krishna Grand Hotel"
		#   distribution_center.address_line4 = "Banashankari Stage II"
		#   distribution_center.details = {"warehouse_code" => "RP03"}
		#   country = LookupValue.where("original_code = ?", "India").first
		#   state = LookupValue.where("original_code = ?", "Karnataka").first
		#   city = LookupValue.where("original_code = ?", "Bangalore").first
		#   distribution_center.distribution_center_type_id = LookupValue.where("code = ?", Rails.application.credentials.distribution_center_types_warehouse).first.try(:id)
		#   distribution_center.country_id = country.id
		#   distribution_center.state_id = state.id
		#   distribution_center.city_id = city.id
		#   distribution_center.city_id = city.id
		#   distribution_center.code = "RP03"
		# end

		# # Creation of Store User and Assigining Distribution Center Users
		# User.find_or_create_by!(username: "store_user") do |user|
		#   user.first_name = "Store"
		#   user.last_name = "Enterprises"
		#   user.email = "store_user@blubirch.com"
		#   user.password = "blubirch123"
		#   user.password_confirmation = "blubirch123"
		#   role = Role.where(name: "Store User", code: "store_user").first
		#   user.roles = [role]
		#   distribution_center = DistributionCenter.where(name: "A066").first
		#   user.distribution_centers = [distribution_center]
		# end

		# # Creation of Users and Assigining Distribution Center Users
		# User.find_or_create_by!(username: "warehouse") do |user|
		#   user.first_name = "Warehouse"
		#   user.last_name = "User"
		#   user.email = "warehouse@blubirch.com"
		#   user.password = "blubirch123"
		#   user.password_confirmation = "blubirch123"
		#   role = Role.where(name: "Warehouse User", code: "warehouse").first
		#   user.roles = [role]
		#   distribution_center = DistributionCenter.where(name: "RP03").first
		#   user.distribution_centers = [distribution_center]
		# end

		# Creation of Client
		Client.find_or_create_by!(name: "Croma") do |client|
		  client.domain_name = "http://www.croma.com"
		  client.address_line1 = "2/1, 27th Cross"
		  client.address_line2 = "7th Main Rd"
		  client.address_line3 = "Behind Krishna Grand Hotel"
		  client.address_line4 = "JP Nagar Phase II"
		  country = LookupValue.where("original_code = ?", "India").first
		  state = LookupValue.where("original_code = ?", "Karnataka").first
		  city = LookupValue.where("original_code = ?", "Bangalore").first
		  client.country_id = country.id
		  client.state_id = state.id
		  client.city_id = city.id
		end

		# #Import Attribute Masters
		# AttributeMaster.import_attributes

		# #Import Categories
		# Category.import_categories

		#Import Attribute Masters
		# ClientAttributeMaster.import_client_attributes

		#Import Categories
		# ClientCategory.import_client_categories

		#Import Customer Return Reason
		# CustomerReturnReason.import

		# Import Ctaegory Grading Test Rules
		# CategoryGradingRule.import_test_rule

		# Import Customer Return Reason
		
		# CategoryGradingRule.import_grading_rule(nil,"Warehouse")

		# Import Ctaegory Grading Test Rules
		# ClientCategoryGradingRule.import_client_test_rule

		# ClientCategoryGradingRule.import_client_test_rule_trial
		# ClientCategoryGradingRule.import_client_test_rule(nil,"Warehouse")

		#Import Customer Return Reason
		# ClientCategoryGradingRule.import_client_grading_rule(nil,"Warehouse")


		#Import Client SKU Masters
		# ClientSkuMaster.import_client_sku_masters

		# Rule.import_disposition_rules

		# Client Disposition Rule Import
		# Rule.import_client_disposition_rules

		# STN Document Import
		# GatePass.import
			
  end
	
end
