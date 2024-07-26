class Api::V1::Warehouse::ItemInformationsController < ApplicationController

	def search
    inventory_information = InventoryInformation.where("lower(tag_number) = ?", params[:tag_number].downcase.strip) if params[:tag_number].present?
    if inventory_information.present? && params[:tag_number].present?
      render json: inventory_information
    else
      render json: "Tag Number not found", status: :unprocessable_entity
    end
  end

end
