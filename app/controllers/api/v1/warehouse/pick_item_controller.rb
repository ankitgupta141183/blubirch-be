class Api::V1::Warehouse::PickItemController < ApplicationController

  def index
    @inventories = Inventory.where("details ->> 'packaging_status' = ? ", 'Pending Picking').where("(details ->> 'pick')::boolean = true").order('updated_at desc').page(@current_page).per(@per_page)
    if @inventories.present?
      render json: @inventories, meta: pagination_meta(@inventories)
    else
      render json: "No Inventories Found", status: :unprocessable_entity
    end
  end

  def get_inventories
    @inventories = Inventory.where(id: params[:ids])
    if @inventories.present?
      render json: @inventories
    else
      render json: "No Inventories Found", status: :unprocessable_entity
    end
  end

  def create_items
    if params["toats"].present?
      params["toats"].each do |toat|
        @inventories = Inventory.where(id: toat['inventories'])
        toat_no = toat['toat_number']
        @inventories.each do |i|
          i.details['toat_number'] = toat_no
          i.details['packaging_status'] = 'Pending Package'
          i.save
        end
      end
      render json: @inventories
    else
      render json: "Can not create items", status: :unprocessable_entity
    end
  end

end