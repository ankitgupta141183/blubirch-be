class Api::V1::Warehouse::Wms::StowingController < ApplicationController

  def fetch_inventories
    if params["toat_number"].present?
      distribution_centers_ids = @current_user.distribution_centers.pluck(:id)
      @inventories = Inventory.where(distribution_center_id: distribution_centers_ids, toat_number: params["toat_number"]).order('updated_at desc')
      render json: { inventories: @inventories, status: 200}
    else
      render json: {message: "Wrong Parameters", status: 302}
    end
  end

  def unstowed_items
    result = []
    set_pagination_params(params)
    distribution_centers_ids = @current_user.distribution_centers.pluck(:id)
    toat_numbers = Inventory.where(distribution_center_id: distribution_centers_ids).page(1).per(20).pluck(:toat_number).reject { |e| e.to_s.empty? }.uniq
    
    toat_numbers.each do |toat|
      inventories = Inventory.where(distribution_center_id: distribution_centers_ids, toat_number: toat)
      result << {"toat_number" => toat, "quantity" => inventories.size, "last_updated_at" => inventories.map{|h| h[:updated_at]}.max }
    end
    render json: { result: result, status: 200 } if result.present?
    render json: {message: "Not Found", status: 302} if result.blank?
  end

  def set_location
    @inventory = Inventory.find(params['id'])
    if params['location'].present?
      @inventory.update_attributes(aisle_location: params['location'])
      render json: { inventory: @inventory, status: 200 }
    end
  end

  def complete_stowing
    distribution_centers_ids = @current_user.distribution_centers.pluck(:id)
    @inventories = Inventory.where(distribution_center_id: distribution_centers_ids, toat_number: params['toat_number'])
    @inventories.each do |inventory|
      if inventory.aisle_location.present?
        inventory.toat_number =  nil
        if inventory.details.present?
          inventory.details["stowing_completion_date"] = Time.now.to_s
        else
          inventory.details = {"stowing_completion_date" => Time.now.to_s}
        end
        inventory.save
      end
    end
    render json: {message: "Stowing Completed", status: 200}
  end

end