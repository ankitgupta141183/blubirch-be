class Api::V1::Warehouse::PutAwayController < ApplicationController
  
  def index
    set_pagination_params(params)
    # pending request items
    inventory_ids = RequestItem.joins(:put_request).where("put_requests.status IN (?) OR request_items.status = ?", [1, 2], 3).select(:inventory_id)
    
    if params[:sub_location_status] == "open"
      open_sub_location_ids = SubLocation.location_type_open.select(:id)
      @inventories = Inventory.includes(:distribution_center, :sub_location, :gate_pass).opened.where(sub_location_id: open_sub_location_ids).order(updated_at: :desc)
    else
      @inventories = Inventory.includes(:distribution_center, :sub_location, :gate_pass).not_inwarded.where.not(status: "Pending GRN").where(sub_location_id: nil).where("inventories.details ->> 'issue_type' IS NULL").order(created_at: :asc)
    
      if (params[:search].present? and params[:search_in].present?)
        search_data = params[:search].split(',').collect(&:strip).flatten
        if params[:search_in] == "tag_number"
          @inventories = @inventories.where(tag_number: search_data)
        elsif params[:search_in] == "rdd_number"
          @inventories = @inventories.where("details ->> 'rdd_number' IN (?)", search_data)
        end
      end
    end
    @inventories = @inventories.where.not(id: inventory_ids)
    
    filter_inventories
    
    @inventories = @inventories.page(@current_page).per(@per_page)
    render json: @inventories, each_serializer: PutAwaySerializer, meta: pagination_meta(@inventories)
  end
  
  def update_sub_location
    ActiveRecord::Base.transaction do
      inventories = Inventory.where(id: params[:inventory_ids])
      sub_location = SubLocation.find_by(id: params[:sub_location_id])
      
      inventories.each do |inv|
        raise CustomErrors.new "Request has been created for this item #{inv.tag_number}" if inv.put_request_created?
        raise CustomErrors.new "Item #{inv.tag_number} is already inwarded!" if params[:putaway_type] == "inward" && inv.is_putaway_inwarded?

        inv.assign_attributes({sub_location_id: sub_location.id, is_putaway_inwarded: true})
        inv.details ||= {}
        inv.details["sub_location_updated_at"] = Time.now
        inv.details["sub_location_updated_by"] = current_user.id
        inv.save!
      end

      # in case of not found items
      not_found_items = RequestItem.where(status: "not_found", inventory_id: params[:inventory_ids])
      not_found_items.update_all(status: "location_updated")
      
      render json: {status: :ok}
    end
  end
  
  def not_found
    set_pagination_params(params)
    completed_request_ids = PutRequest.putaway_requests.status_completed.pluck(:id)
    inventory_ids = RequestItem.where(put_request_id: completed_request_ids).status_not_found.pluck(:inventory_id)
    @inventories = Inventory.includes(:distribution_center, :sub_location, :gate_pass).where(id: inventory_ids).order(updated_at: :desc)
    filter_inventories
    
    @inventories = @inventories.page(@current_page).per(@per_page)
    render json: @inventories, each_serializer: PutAwaySerializer, meta: pagination_meta(@inventories)
  end
  
  def request_reasons
    distribution_center = DistributionCenter.find_by(id: params[:distribution_center_id])
    raise CustomErrors.new "Invalid Location!" unless distribution_center.present?
    
    request_types = PutRequest.request_types.keys.map{|k| {id: k, name: k.titleize} }
    put_away_reasons = PutRequest.put_away_reasons.keys.map{|k| {id: k, name: k.titleize} }
    pick_up_reasons = PutRequest.pick_up_reasons.keys.map{|k| {id: k, name: k.titleize} }
    users = distribution_center.users.distinct.as_json(only: [:id, :username], methods: [:full_name])
    
    render json: {request_types: request_types, put_away_reasons: put_away_reasons, pick_up_reasons: pick_up_reasons, users: users}
  end
  
  def sub_locations
    distribution_center = DistributionCenter.find_by(id: params[:distribution_center_id])
    raise CustomErrors.new "Invalid Location!" unless distribution_center.present?
    
    data = distribution_center.sub_locations.as_json(only: [:id, :code])
    render json: {sub_locations: data}
  end
  
  def write_off
    inventory = Inventory.find_by(id: params[:id])
    raise CustomErrors.new "Invalid ID!" unless inventory.present?
    raise CustomErrors.new "Please enter the details!" if (params[:raised_against].blank? || params[:debit_amount].blank?)
    
    not_found_items = RequestItem.status_not_found.where(inventory_id: inventory.id)
    raise CustomErrors.new "Not found items are not present." unless not_found_items.present?
    
    not_found_items.update_all(status: "wrote_off", raised_against: params[:raised_against], debit_amount: params[:debit_amount])
    inventory.outward_inventory!(@current_user)
    
    render json: {status: :ok}
  end
  
  # request creation
  def all_inventories
    set_pagination_params(params)
    disposition = params[:disposition]
    raise CustomErrors.new "Please select Disposition!" if disposition.blank?
    
    @inventories = Inventory.includes(:distribution_center, :sub_location, :gate_pass).opened.where(disposition: disposition, is_putaway_inwarded: true)
    
    dc_ids = @distribution_center.present? ? [@distribution_center.id] : current_user.distribution_centers.select(:id)
    @inventories = @inventories.where(distribution_center_id: dc_ids)
    # pending request items
    inventory_ids = RequestItem.joins(:put_request).where("put_requests.status IN (?) OR request_items.status = ?", [1, 2], 3).select(:inventory_id)
    @inventories = @inventories.where.not(id: inventory_ids)
    
    if params[:search].present?
      tag_numbers = params[:search].split(',').collect(&:strip).flatten
      @inventories = @inventories.where(tag_number: tag_numbers)
    end
    
    @inventories = @inventories.page(@current_page).per(@per_page)
    render json: @inventories, each_serializer: PutAwaySerializer, meta: pagination_meta(@inventories)
  end
  
  def get_dispositions
    dispositions = ["Brand Call-Log", "Redeploy", "Liquidation", "Repair", "Pending Disposition", "Insurance", "Restock"]
    data = dispositions.map{|d| {key: d, value: d}}
    render json: {dispositions: data}
  end
  
  def filters_data
    rules_csv = CSV.read("#{Rails.root}/public/master_files/sub_location_rules.csv", :headers=>true)
    categories_csv = CSV.read("#{Rails.root}/public/master_files/client_category_attributes.csv", :headers=>true)
    
    categories = categories_csv['Category L3'].uniq.compact.map{|c| {key: c, value: c}}
    brands = ClientSkuMaster.pluck(:brand).uniq.compact.map{|b| {key: b, value: b}}                                                            # brands = Inventory.pluck("details->'brand'").compact.uniq
    grades = rules_csv['Grade'].uniq.compact.map{|g| {key: g, value: g}}
    
    render json: {categories: categories, brands: brands, grades: grades}
  end
  
  
  
  # Temp requirement to update existing inventories
  def export_inventory
    distribution_center = DistributionCenter.find_by_id(params[:location_id])
    raise CustomErrors.new "Invalid Location." if distribution_center.blank?
    
    file_csv = distribution_center.export_uninwarded_items
    
    send_data(file_csv, filename: "#{distribution_center.code}_#{Time.now.to_i}.csv")
  end
  
  def import_inventory
    DistributionCenter.update_sub_locations(params[:file])
    
    render json: { message: "Inventories updated successfully." }
  end
  
  private
  
  def filter_inventories
    dc_ids = @distribution_center.present? ? [@distribution_center.id] : current_user.distribution_centers.select(:id)
    @inventories = @inventories.where(distribution_center_id: dc_ids)
    if params[:tag_number].present?
      tag_numbers = params[:tag_number].split(',').collect(&:strip).flatten
      @inventories = @inventories.where(tag_number: tag_numbers)
    end
    @inventories = @inventories.where("inventories.details ->> 'category_l3' IN (?)", JSON.parse(params[:categories])) if (params[:categories].present? and JSON.parse(params[:categories]).present?)
    @inventories = @inventories.where("inventories.details ->> 'brand' IN (?)", JSON.parse(params[:brands])) if (params[:brands].present? and JSON.parse(params[:brands]).present?)
    @inventories = @inventories.where(grade: JSON.parse(params[:grade])) if (params[:grade].present? and JSON.parse(params[:grade]).present?)
  end
  
  
end
