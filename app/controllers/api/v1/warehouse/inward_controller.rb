class Api::V1::Warehouse::InwardController < ApplicationController

  def get_sku_details
    @clientskumaster = ClientSkuMaster.filter_by_code(params[:sku_code]).last
    if @clientskumaster.present?
      render json: @clientskumaster
    else
      render json: "Unable to get Sku Record", status: :unprocessable_entity
    end
  end

  def create_inventory
    if params[:sku_number].present? && params[:client_id].present?
      client_sku_master = ClientSkuMaster.filter_by_code(params[:sku_number]).last
      distribution_center_id = @current_user.distribution_centers.first.id
      @inventory = Inventory.new(user: @current_user, client_id: params[:client_id], distribution_center_id: distribution_center_id, is_putaway_inwarded: false)
      @inventory.tag_number = "T-#{SecureRandom.hex(3)}".downcase
      @inventory.details = {}
      #create details attributes
      params[:attrs].each do |field|
        if field.present?
          field.each do |key,val|
            @inventory.details[key] = val
          end
        end
      end

      @inventory.details['client_sku_master_id'] = client_sku_master.id if client_sku_master.present?
      if @inventory.save
        inv_status = LookupValue.find_by_code("inv_sts_warehouse_pending_grade")
        @inventory_status = @inventory.inventory_statuses.create(distribution_center: @inventory.distribution_center, status_id: inv_status.id, user: @current_user)
        render json: @inventory
      else
        render json: "Unable to create inventory", status: :unprocessable_entity
      end
    else
      render json: "Unable to create inventory", status: :unprocessable_entity
    end
  end

end