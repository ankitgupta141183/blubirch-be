class Api::V1::Warehouse::EWastesController < ApplicationController

  def fetch_e_wastes
    get_distribution_centers
    ids = @distribution_center.present? ? [@distribution_center.id] : current_user.distribution_centers.pluck(:id)
    @inventories = EWaste.includes(:e_waste_histories).where(distribution_center_id: ids, is_active: true)
    @inventories = @inventories.where("lower(details ->> 'criticality') IN (?) ", params[:criticality]) if params['criticality'].present?
    if current_user.roles.last.name == "Default User"
      @items = check_user_accessibility(@inventories, @distribution_center_detail)
      @inventories = @inventories.where(id: @items.pluck(:id)).order('updated_at desc')
    end
    render json: @inventories
  end

  def search_item
    get_distribution_centers
    set_pagination_params(params)
    ids = @distribution_center.present? ? [@distribution_center.id] : current_user.distribution_centers.pluck(:id)
    @e_wastes = EWaste.where(status: params['status'], is_active: true, distribution_center_id: ids).where("lower(tag_number) = ? OR lower(serial_number) = ? OR lower(serial_number_2) = ? OR details ->> 'brand' = ?", params['search'].downcase, params['search'].downcase, params['search'].downcase, params['search']).page(@current_page).per(@per_page)
    @e_wastes = @e_wastes.where("lower(details ->> 'criticality') IN (?) ", param[:criticality].map(&:downcase)) if params['criticality'].present?
    render json: @e_wastes, meta: pagination_meta(@e_wastes)
  end

  def generate_csv
    EWasteInventoriesWorker.perform_async(current_user.id)
    render json: "success"
  end

  def create_lots
    EWaste.import_lots(params[:file])
    render json: "success"
  end

  def update_ewaste_cell
    column_name =  params[:column_name]  
    column_value =  params[:column_value]
    data_id =  params[:id]
    @liquidation_obj = EWaste.find(data_id)
    @liquidation_obj.send "#{column_name}=".to_sym, column_value 
    if @liquidation_obj.save 
       render json: @liquidation_obj
    else
       render json: @liquidation_obj.errors, status: :unprocessable_entity
    end
  end  

  def get_vendor_ewaste
    @vendor_master = VendorMaster.joins(:vendor_types).where('vendor_types.vendor_type': 'EWaste').distinct
    render json: @vendor_master
  end

  private

  def check_user_accessibility(items, detail)
    result = []
    items.each do |item|
      origin_location_id = DistributionCenter.where(code: item.details["destination_code"]).pluck(:id)
      if ( (detail["grades"].include?("All") ? true : detail["grades"].include?(item.grade) ) && ( detail["brands"].include?("All") ? true : detail["brands"].include?(item.inventory.details["brand"]) ) && ( detail["warehouse"].include?(0) ? true : detail["warehouse"].include?(item.distribution_center_id) ) && ( detail["origin_fields"].include?(0) ? true : detail["origin_fields"].include?(origin_location_id)) )
        result << item 
      end
    end
    return result
  end

  def get_distribution_centers
    @distribution_center_ids = @distribution_center.present? ? [@distribution_center.id] : current_user.distribution_centers.pluck(:id)
    @distribution_center_detail = ""
    if ["Default User", "Site Admin"].include?(current_user.roles.last.name)
      id = []
      if @distribution_center.present?
        ids = [@distribution_center.id]
      else
        ids = current_user.distribution_centers.pluck(:id)
      end
      current_user.distribution_center_users.where(distribution_center_id: ids).each do |distribution_center_user|
        @distribution_center_detail = distribution_center_user.details.select{|d| d["disposition"] == "E-Waste" || d["disposition"] == "All"}.last
        if @distribution_center_detail.present?
          @distribution_center_ids = @distribution_center_detail["warehouse"].include?(0) ? DistributionCenter.all.pluck(:id) : @distribution_center_detail["warehouse"]
        end
      end
    else
      @distribution_center_ids = DistributionCenter.all.pluck(:id)
    end
  end

end