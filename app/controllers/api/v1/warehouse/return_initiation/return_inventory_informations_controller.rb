class Api::V1::Warehouse::ReturnInitiation::ReturnInventoryInformationsController < ApplicationController

	def index
		set_pagination_params(params)
    return_inventory_information_new_status = LookupValue.where(code: Rails.application.credentials.return_inventory_information_new_status).last
    return_inventory_informations = ReturnInventoryInformation.where(status_id: return_inventory_information_new_status.try(:id)).reorder(updated_at: :desc).page(@current_page).per(@per_page)
    render json: return_inventory_informations, meta: pagination_meta(return_inventory_informations)
	end

  def search_return_items
    if params[:search_type] == "Reference Document"
      return_inventory_informations = ReturnInventoryInformation.where("LOWER(reference_document_number) ilike (?)", "%#{params[:search].try(:downcase)}%")
    elsif params[:search_type] == "Article ID"
      return_inventory_informations = ReturnInventoryInformation.where("LOWER(sku_code) ilike (?)", "%#{params[:search].try(:downcase)}%")
    elsif params[:search_type] == "Serial Number"
      return_inventory_informations = ReturnInventoryInformation.where("LOWER(serial_number) ilike (?)", "%#{params[:search].try(:downcase)}%")
    elsif params[:search_type] == "Article ID & Serial Number"
      return_inventory_informations = ReturnInventoryInformation.where("LOWER(sku_code) ilike (?) and LOWER(serial_number) ilike (?)", "%#{params[:article].try(:downcase)}%", "%#{params[:serial_number].try(:downcase)}%")
    end
    render json: return_inventory_informations
  end

end
