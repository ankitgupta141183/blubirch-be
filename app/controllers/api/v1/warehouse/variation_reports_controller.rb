class Api::V1::Warehouse::VariationReportsController < ApplicationController

  def index
    set_pagination_params(params)
    inventories = Inventory.filter(filtering_params).includes(:inventory_grading_details, :inventory_statuses).
    where("inventory_grading_details.is_active = ? and inventory_statuses.is_active = ?", true, true)
    .references(:inventory_grading_details).page(@current_page).per(@per_page)
    @inventories = [] 
    inventories.each do |inventory|
      if inventory.inventory_grading_details.present?
        if inventory.inventory_grading_details.first.grade_id != inventory.inventory_grading_details.last.grade_id 
          @inventories << inventory
        end
      end
    end
    render json: @inventories, meta: pagination_meta(inventories) if @inventories.present?
    render json: "Data not Present", status: :unprocessable_entity if @inventories.blank?
  end

  private
  def filtering_params
    params.slice(:tag_number)
  end
end