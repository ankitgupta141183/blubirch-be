class Api::V1::Warehouse::AlertInventoriesController < ApplicationController

  def index
    @alert_inventories = AlertInventory.all
    if @alert_inventories.present?
      render json: @alert_inventories
    else
      render json: "Data not Present", status: :unprocessable_entity
    end
  end

end