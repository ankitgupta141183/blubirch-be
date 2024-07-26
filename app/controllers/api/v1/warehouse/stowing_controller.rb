class Api::V1::Warehouse::StowingController < ApplicationController

  def fetch_inventories
    if params["toat_number"].present?
      @inventories = Inventory.where("LOWER(inventories.details ->> 'toat_number') = ? AND inventories.details ->> 'decision' = ?", params["toat_number"].downcase, "Pass").order('updated_at desc')
      render json: { inventories: @inventories }
    else
      render json: "Wrong Parameters", status: :unprocessable_entity
    end
  end

  def set_location
    @inventory = Inventory.find(params['id'])
    @inventory.details['location'] = params['location']
    @inventory.details['packaging_status'] = "Found"
    @inventory.save
    render json: { inventory: @inventory }
  end

  def complete_stowing
    Inventory.where(id: params['inventory_ids']).update_all("details = jsonb_set(details, '{packaging_status}', to_json('Pending Picking'::text)::jsonb)") if params['inventory_ids'].present?
    Inventory.where(id: params['not_found_ids']).update_all("details = jsonb_set(details, '{packaging_status}', to_json('Not Found'::text)::jsonb)") if params['not_found_ids'].present?
    render json: "Stowing Completed", status: 200
  end

end