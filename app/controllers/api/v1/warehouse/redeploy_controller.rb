class Api::V1::Warehouse::RedeployController < ApplicationController
  before_action :set_redeploy, only: [:update_redeploy_details]
  
  # GET /api/v1/warehouse/redeploy
  def index
    set_pagination_params(params)
    get_distribution_centers_new
    ids = @distribution_center.present? ? [@distribution_center.id] : current_user.distribution_centers.pluck(:id)
    @redeployees = Redeploy.dc_filter(ids).where(is_active: true).order('redeploys.created_at desc')
    # @redeployees = @redeployees.joins(:inventory).where("inventories.is_putaway_inwarded IS NOT false")

    if current_user.roles.last.name == "Default User"
      @items = check_user_accessibility(@redeployees, @distribution_center_detail)
      @redeployees = @redeployees.where(id: @items.pluck(:id))
    end
    @redeployees = @redeployees.where("lower(redeploys.details ->> 'criticality') IN (?) ", params[:criticality]) if params['criticality'].present?
    @redeployees = @redeployees.page(@current_page).per(@per_page)
    render json: @redeployees, meta: pagination_meta(@redeployees)
  end

  def search_item
    set_pagination_params(params)
    get_distribution_centers_new
    search_param = params['search'].split(',').collect(&:strip).flatten
    ids = @distribution_center.present? ? [@distribution_center.id] : current_user.distribution_centers.pluck(:id)
    @redeployees = Redeploy.where(is_active: true, distribution_center_id: ids).where("lower(redeploys.#{params['search_in']}) IN (?) ", search_param.map(&:downcase))
    # @redeployees = @redeployees.joins(:inventory).where("inventories.is_putaway_inwarded IS NOT false")
    @redeployees = @redeployees.where("lower(redeploys.details ->> 'criticality') IN (?) ", params[:criticality]) if params['criticality'].present?
    @redeployees = @redeployees.page(@current_page).per(@per_page)
    render json: @redeployees, meta: pagination_meta(@redeployees)
  end

  # PUT /api/v1/warehouse/redeploy/:id/update_redeploy_details
  def update_redeploy_details
		redeploy_params   = params[:redeploy_details]
    current_status    = redeploy_params[:status]
    current_status_id = LookupValue.find_by(original_code: current_status).try(:id)
    next_status       = next_status(current_status)
    next_status_id    = LookupValue.find_by(original_code: next_status).try(:id)
    if redeploy_params[:files].present?
      redeploy_params[:files].each do |file|
        @redeploy.redeploy_attachments.create(attachment_file: file, attachment_file_type: current_status , attachment_file_type_id: current_status_id )
      end
    end

    @redeploy.destination_code      			= redeploy_params[:destination_code] if redeploy_params[:destination_code].present?
    @redeploy.pending_destination_remarks = redeploy_params[:pending_destination_remarks] if redeploy_params[:pending_destination_remarks].present?
    @redeploy.status                      = next_status
    @redeploy.status_id                   = next_status_id
    if @redeploy.save
      @redeploy.create_history(current_user.id)
      render json: @redeploy
    else
      render json: @redeploy.errors, status: :unprocessable_entity
    end
  end

  def get_vendor_redeploy
    @vendor_master = VendorMaster.joins(:vendor_types).where('vendor_types.vendor_type': ["Redeploy", "Internal Vendor"]).distinct
    render json: @vendor_master
  end

  def get_distribution_centers
    centers = DistributionCenter.where("site_category in (?)", ["A", "D", "B", "R"])
    render json: centers
  end

  def create_redeploy_dispatch_order

    # Step-1 Redeploy Order create
    # Step-2 Warehouse Order create
    # Step-3 Warehouse Order Item create
    # Step-4 Redeploy History create

    redeploy_data = Redeploy.where(id: params[:redeploy_ids]) || []
    if redeploy_data.blank? || params[:vendor_code].blank?
      render json: "Please Provide Valid Inputs", status: :unprocessable_entity
    else
      #-- Step-1 --
      redeploy_order = RedeployOrder.new(vendor_code: params[:vendor_code], order_number: "OR-RED-#{SecureRandom.hex(6)}", lot_name: params[:lot_name].to_s.strip)
      redeploy_order.save!
      #-- Step-2 --
      #-----
      inv = redeploy_data.first.inventory
      #-----
      warehouse_order                = redeploy_order.warehouse_orders.new(distribution_center_id: inv.distribution_center_id, vendor_code: params[:vendor_code])
      warehouse_order_status         = LookupValue.find_by(code: Rails.application.credentials.order_status_warehouse_pending_pick)
      warehouse_order.client_id      = inv.client_id rescue nil
      warehouse_order.status_id      = warehouse_order_status.id
      warehouse_order.total_quantity = redeploy_data.count
      warehouse_order.save
      original_code, status_id = LookupStatusService.new("Dispatch", "pending_pick_and_pack").call
      redeploy_data.each do |redeploy|
        redeploy.update(redeploy_order_id: redeploy_order.id)
        redeploy.update(status_id: status_id, status: original_code, redeploy_order_id: redeploy_order.id, is_active: false)
        #-- Step-3 --
        client_category = ClientSkuMaster.find_by_code(redeploy.sku_code).client_category rescue nil
        warehouse_order_item                      = warehouse_order.warehouse_order_items.new
        warehouse_order_item.inventory_id         = redeploy.inventory_id 
        warehouse_order_item.client_category_id   = client_category.id rescue nil
        warehouse_order_item.client_category_name = client_category.name rescue ''
        warehouse_order_item.sku_master_code      = redeploy.sku_code
        warehouse_order_item.item_description     = redeploy.item_description
        warehouse_order_item.tag_number           = redeploy.tag_number
        warehouse_order_item.serial_number        = redeploy.inventory.serial_number rescue ''
        warehouse_order_item.quantity             = 1
        warehouse_order_item.status               = warehouse_order_status.original_code
        warehouse_order_item.status_id            = warehouse_order_status.id
        warehouse_order_item.toat_number          = redeploy.toat_number
        warehouse_order_item.aisle_location       = redeploy.aisle_location
        warehouse_order_item.details              = redeploy.inventory.details
        warehouse_order_item.save
        #-- Step-4 --
        details = { "#{original_code.try(:downcase).try(:strip).split(' ').join('_')}_created_at" => Time.now,
          "status_changed_by_user_id" => current_user.id,
          "status_changed_by_user_name" => current_user.full_name,
        }
        redeploy.redeploy_histories.create(status_id: status_id, details: details)
      end
      render json: {order_number: redeploy_order.order_number}
    end
  end

  def get_dispositions
    lookup_key = LookupKey.find_by_code('WAREHOUSE_DISPOSITION')
    dispositions = lookup_key.lookup_values.where.not(original_code: ['Redeploy', 'Pending Transfer Out', 'RTV', 'Capital Asset']).order('original_code asc')
    policy_key = LookupKey.find_by_code('POLICY')
    policies = policy_key.lookup_values
    render json: {dispositions: dispositions.as_json(only: [:id, :original_code]), policies: policies.as_json(only: [:id, :original_code])}
  end

  def set_disposition
    disposition = LookupValue.find_by_id(params[:disposition])
    @redeployees = Redeploy.includes(:inventory).where(id: params[:redeploy_ids])
    policy = LookupValue.find_by_id(params['policy']) if params['policy'].present?
    if @redeployees.present? && disposition.present?
      @redeployees.each do |redeploy|
        begin
          ActiveRecord::Base.transaction do
            inventory = redeploy.inventory
            redeploy.details['disposition_set'] = true
            redeploy.is_active = false
            inventory.disposition = disposition.original_code
            if disposition.original_code == 'Liquidation'
              redeploy.details['policy_id'] = policy.id
              redeploy.details['policy_type'] = policy.original_code
              inventory.details['policy_id'] = policy.id
              inventory.details['policy_type'] = policy.original_code
            end
            redeploy.details['disposition_remark'] = params['desposition_remarks']
            inventory.disposition = disposition.original_code
            inventory.save
            redeploy.save
            if params[:files].present?
              params[:files].each do |file|
                @redeploy.redeploy_attachments.create(attachment_file: file, attachment_file_type: "Disposition" , attachment_file_type_id: 806)
              end
            end
            DispositionRule.create_bucket_record(disposition.original_code, inventory, 'Redeploy', current_user.id)
          end
        rescue ActiveRecord::RecordInvalid => exception
          render json: "Something Went Wrong", status: :unprocessable_entity
          return
        end
      end

      render json: "success", status: 200
    else
      render json: "Please provide Valid Ids", status: :unprocessable_entity
    end
  end

  private
  def set_redeploy
  	@redeploy = Redeploy.find(params[:id])
  end

  def next_status(status)
    p_r_destination = LookupValue.find_by(code: Rails.application.credentials.redeploy_status_pending_redeploy_destination).original_code
    p_r_dispatch    = LookupValue.find_by(code: Rails.application.credentials.redeploy_status_pending_redeploy_dispatch).original_code
    if(status == p_r_destination)
      p_r_dispatch
    else
      status
    end  
  end

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

  def get_distribution_centers_new
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
        @distribution_center_detail = distribution_center_user.details.select{|d| d["disposition"] == "Redeploy" || d["disposition"] == "All"}.last
        if @distribution_center_detail.present?
          @distribution_center_ids = @distribution_center_detail["warehouse"].include?(0) ? DistributionCenter.all.pluck(:id) : @distribution_center_detail["warehouse"]
          return
        end
      end
    else
      @distribution_center_ids = @distribution_center.present? ? [@distribution_center.id] : DistributionCenter.all.pluck(:id)
    end
  end
end	