class Api::V1::Warehouse::ReturnInitiation::MasterValuesController < ApplicationController

	skip_before_action :check_permission

	def return_types
		lookup_key = LookupKey.where("code = ?", Rails.application.credentials.return_types).last 
		render json: lookup_key.lookup_values
	end

	def channel_types
		lookup_key = LookupKey.where("code = ?", Rails.application.credentials.channel_types).last 
		render json: lookup_key.lookup_values
	end

	def return_sub_types
		lookup_value = LookupValue.where("id = ?", params[:lookup_value_id]).last
		lookup_values = lookup_value.children
		render json: lookup_values
	end

	def return_reasons
		lookup_value = LookupValue.where("id = ?", params[:lookup_value_id]).last
		lookup_values = lookup_value.children
		render json: lookup_values
	end

	def return_sub_reasons
		lookup_value = LookupValue.where("id = ?", params[:lookup_value_id]).last
		lookup_values = lookup_value.children
		render json: lookup_values
	end

	def return_creation_locations
		lookup_key = LookupKey.where("code = ?", Rails.application.credentials.retrun_creation_locations).last 
		render json: lookup_key.lookup_values
	end

	def return_creation_document_keys
		lookup_key = LookupKey.where("code = ?", Rails.application.credentials.return_creation_document_keys).last 
		render json: lookup_key.lookup_values
	end

	def return_request_creation_status
		lookup_key = LookupKey.where("code = ?", Rails.application.credentials.return_request_creation_status).last 
		render json: lookup_key.lookup_values
	end

	def return_incident_damage_types
		lookup_key = LookupKey.where("code = ?", Rails.application.credentials.return_creation_incident_damage_types).last 
		render json: lookup_key.lookup_values
	end

	def return_type_of_loss
		lookup_key = LookupKey.where("code = ?", Rails.application.credentials.return_creation_type_of_loss).last 
		render json: lookup_key.lookup_values
	end

	def return_salvage_values
		lookup_key = LookupKey.where("code = ?", Rails.application.credentials.return_creation_salvage_values).last 
		render json: lookup_key.lookup_values
	end

	def return_incident_locations
		lookup_key = LookupKey.where("code = ?", Rails.application.credentials.return_creation_incident_locations).last 
		render json: lookup_key.lookup_values
	end

	def return_vendor_responsible
		lookup_key = LookupKey.where("code = ?", Rails.application.credentials.return_creation_vendor_responsible).last 
		render json: lookup_key.lookup_values
	end

	def sales_return_settlement_type
		lookup_key = LookupKey.where("code = ?", Rails.application.credentials.sales_return_preffered_settlement_type).last 
		render json: lookup_key.lookup_values
	end

	def sales_return_settlement_type
		lookup_key = LookupKey.where("code = ?", Rails.application.credentials.sales_return_preffered_settlement_type).last 
		render json: lookup_key.lookup_values
	end

	def return_initiation_dispostions
		lookup_key = LookupKey.where("code = ?", Rails.application.credentials.return_initiation_dispositions).last 
		render json: lookup_key.lookup_values
	end

end
