class Api::V1::Warehouse::ReplacementsController < ApplicationController

  before_action :get_dispatch_items, :dispatch_item_filters, only: :dispatch_items

  before_action :get_dispatch_item, only: :dispatch_item

  # GET api/v1/warehouse/insurances
  def index
    get_replacements
    filter_replacements
    if current_user.roles.last.name == "Default User"
      @items = check_user_accessibility(@replacements, @distribution_center_detail)
      @replacements = @replacements.where(id: @items.pluck(:id)).order('replacements.updated_at desc')
    end
    @replacements = @replacements.page(@current_page).per(@per_page)
    render json: @replacements, include: 'replacement_attachments', meta: pagination_meta(@replacements)
  end

  def show
    replacement = Replacement.find(params[:id])
    render json: replacement
  end

  def update_confirmation
    raise CustomErrors.new "replacement_ids cannot be blank" if params[:ids].blank?
    raise CustomErrors.new "return method cannot be blank" if params[:return_method].blank?
    raise CustomErrors.new "return date cannot be blank" if params[:return_date].blank?
    
    @replacements = Replacement.where(id: params[:ids].to_s.strip.split(','))
    raise CustomErrors.new "No replacements present" if @replacements.blank?

    begin
      ActiveRecord::Base.transaction do
        @replacements.each do |replacement|
          raise CustomErrors.new "Vendor can't be blank" if replacement.vendor.blank?
          #raise CustomErrors.new "Status is already confirmed" if replacement.is_confirmed?
          replacement.update!(return_method: Replacement.return_methods[params[:return_method].to_s.downcase], return_date: params[:return_date].to_date, is_confirmed: true)
        end
        if (Date.parse(params[:return_date].to_s) - Date.parse(Date.current.to_s)).to_i > 7
          return render json: { message: "Return Date is more than 7 days. thus will stay in Pending Confirmation" } 
        end
        create_dispatch_items
      end
      render json: { message: "#{@replacements.size} item(s) successfully 'Updated'" }
      return
    rescue ActiveRecord::RecordInvalid => exception
      render json: exception.message, status: :unprocessable_entity
      return
    end
  end

  def dispatch_items
    if @warehouse_order_items.present?
      @warehouse_order_items = @warehouse_order_items.page(@current_page).per(@per_page)
      render json: @warehouse_order_items, each_serializer: Api::V1::Warehouse::ReplacementWarehouseOrderItemSerializer, meta: pagination_meta(@warehouse_order_items) 
    else
      render json: @warehouse_order_items, meta: pagination_meta(@warehouse_order_items) 
    end
  end

  def dispatch_item
    render json: @warehouse_order_item, serializer: Api::V1::Warehouse::ReplacementWarehouseOrderItemSerializer
  end


  def search_item
    set_pagination_params(params)
    if @distribution_center.present?
      @distribution_center_ids = [@distribution_center.id]
    else
      get_distribution_centers
    end
    ids = @distribution_center.present? ? [@distribution_center.id] : current_user.distribution_centers.pluck(:id)
    search_param = params['search'].split(',').collect(&:strip).flatten
    @replacements = Replacement.joins(:inventory).where(status: params['status'].to_s.split(","), is_active: true, distribution_center_id: ids).where("lower(replacements.#{params['search_in']}) IN (?) ", search_param.map(&:downcase))
    # @replacements = @replacements.where("inventories.is_putaway_inwarded IS NOT false")
    @replacements = @replacements.where("lower(replacements.details ->> 'criticality') IN (?) ", params[:criticality]) if params['criticality'].present?
    @replacements = @replacements.page(@current_page).per(@per_page)
    render json: @replacements, meta: pagination_meta(@replacements)
  end

  def submit_for_inspection
    replacements = Replacement.where(id: params[:replacement_ids])

    if replacements.present?
      replacements.each do |replacement|
        begin
          ActiveRecord::Base.transaction do
            replacemant_status = LookupValue.find_by_code(Rails.application.credentials.replacement_status_pending_replacement_inspection)
            file_type = LookupValue.find_by_code(Rails.application.credentials.replacement_file_type_replacement_call_log)
            replacement.status_id = replacemant_status.id
            replacement.status = replacemant_status.original_code
            replacement.call_log_id = params['call_log_id'].gsub(/[^0-9A-Za-z\\-]/, '')
            replacement.call_log_date = params['call_log_date'].to_datetime
            replacement.call_log_remarks = params['call_log_remark']
            replacement.inventory.details['replacement_status'] = replacemant_status.original_code
            replacement.inventory.save
            if replacement.save!
              if params["files"].present?
                params["files"].each do |file|
                  replacement.replacement_attachments.create!(attachment_file: file, attachment_type: file_type.original_code, attachment_type_id: file_type.id)
                end
              end
              rh = replacement.replacement_histories.new(status_id: replacement.status_id)
              rh.details = {}
              key = "#{replacement.status.try(:downcase).try(:strip).split(' ').join('_')}_created_at"
              rh.details[key] = Time.now
              rh.details["status_changed_by_user_id"] = current_user.id
              rh.details["status_changed_by_user_name"] = current_user.full_name
              rh.save!
            end
          end
        rescue ActiveRecord::RecordInvalid => exception
          render json: "Something Went Wrong", status: :unprocessable_entity
          return
        end
      end
      get_replacements
      @replacements = @replacements.page(@current_page).per(@per_page)
      render json: @replacements
    else
      render json: "Please provide Valid Id", status: :unprocessable_entity
    end
  end

  def submit_inspection
    replacements = Replacement.where(id: params[:replacement_ids])
    replacement_status = LookupValue.find_by_code(Rails.application.credentials.replacement_status_pending_replacement_resolution)
    file_type = LookupValue.find_by_code(Rails.application.credentials.replacement_file_type_replacement_inspection)
    replacement_location = LookupValue.find_by_original_code(params['replacement_location'])
    if replacements.present?
      replacements.each do |replacement|
        begin
          ActiveRecord::Base.transaction do
            replacement.replacement_date = params['email_date'].to_datetime
            replacement.replacement_remark = params['inspection_remark']
            replacement.replacement_location = replacement_location.original_code
            replacement.replacement_location_id = replacement_location.id
            replacement.rgp_number = params['rgp_number']
            replacement.status_id = replacement_status.id
            replacement.status = replacement_status.original_code
            replacement.inventory.details['replacement_status'] = replacement_status.original_code
            if replacement.save!
              replacement.inventory.save
              if params["files"].present?
                params["files"].each do |file|
                  replacement.replacement_attachments.create!(attachment_file: file, attachment_type: file_type.original_code, attachment_type_id: file_type.id)
                end
              end
              rh = replacement.replacement_histories.new(status_id: replacement.status_id)
              rh.details = {}
              key = "#{replacement.status.try(:downcase).try(:strip).split(' ').join('_')}_created_at"
              rh.details[key] = Time.now
              rh.details["status_changed_by_user_id"] = current_user.id
              rh.details["status_changed_by_user_name"] = current_user.full_name
              rh.save!
            end
          end
        rescue ActiveRecord::RecordInvalid => exception
          render json: "Something Went Wrong", status: :unprocessable_entity
          return
        end
      end
      get_replacements
      @replacements = @replacements.page(@current_page).per(@per_page)
      render json: @replacements
    else
      render json: "Please provide Valid Id", status: :unprocessable_entity
    end
  end

  def approve_reject_replacement
    if params['action_type'] == 'Approve'
      file_type = LookupValue.find_by_code(Rails.application.credentials.replacement_file_type_replacement_approved)
      replacement_status = LookupValue.find_by_code(Rails.application.credentials.replacement_status_pending_replacement_approved)
    elsif params['action_type'] == 'Reject'
      file_type = LookupValue.find_by_code(Rails.application.credentials.replacement_file_type_replacement_reject)
      replacement_status = LookupValue.find_by_code(Rails.application.credentials.replacement_status_pending_replacement_disposition)
    end
    replacements = Replacement.where(id: params[:replacement_ids])
    #Check if inventory is already in Approved/Rejected
    if replacements.present?
      replacements.each do |replacement|
        begin
          ActiveRecord::Base.transaction do
            replacement.status_id = replacement_status.id
            replacement.status = replacement_status.original_code
            replacement.action_remark = params[:action_remark]
            replacement.resolution_date = Time.now
            replacement.inventory.details['replacement_status'] = replacement_status.original_code

            if replacement.save!
              replacement.inventory.save
              if params["files"].present?
                params["files"].each do |file|
                  replacement.replacement_attachments.create!(attachment_file: file, attachment_type: file_type.original_code, attachment_type_id: file_type.id)
                end
              end
              rh = replacement.replacement_histories.new(status_id: replacement.status_id)
              rh.details = {}
              key = "#{replacement.status.try(:downcase).try(:strip).split(' ').join('_')}_created_at"
              rh.details[key] = Time.now
              rh.details["status_changed_by_user_id"] = current_user.id
              rh.details["status_changed_by_user_name"] = current_user.full_name
              rh.save!
            end
          end
        rescue ActiveRecord::RecordInvalid => exception
          render json: "Something Went Wrong", status: :unprocessable_entity
          return
        end
      end
      get_replacements
      @replacements = @replacements.page(@current_page).per(@per_page)
      render json: @replacements
    else
      render json: "Please provide Valid id", status: :unprocessable_entity
    end
  end

  def create_replacement
    replacement = Replacement.find_by_id(params[:replacement_id])
    file_type = LookupValue.find_by_code(Rails.application.credentials.replacement_file_type_replacement_detail)
    replacement_status = LookupValue.find_by_code(Rails.application.credentials.replacement_status_pending_redeployment)
    closed_status = LookupValue.find_by_code(Rails.application.credentials.replacement_status_pending_replacement_closed)
    inventory_closed = LookupValue.find_by_code(Rails.application.credentials.inventory_status_warehouse_closed_successfully)
    inventory_open = LookupValue.find_by_code(Rails.application.credentials.inventory_status_warehouse_pending_replacement)
    client_sku_master = ClientSkuMaster.find_by_code(params[:article_id]) if params[:article_id].present?
    if params[:tag_number].present? && Inventory.where(tag_number: params[:tag_number]).present?
      render json: {message: "This tag number already taken", status: 302}
    else
      params[:tag_number] = params[:tag_number].delete(' ')
      params[:tag_number].gsub(/[^a-zA-Z. -]/, '')
      if replacement.present?
        # Create New Inventory
        begin
          ActiveRecord::Base.transaction do
            old_inventory = replacement.inventory
            new_inventory = old_inventory.dup
            new_inventory.serial_number = params[:sr_number1]
            new_inventory.serial_number_2 = params[:sr_number2]
            new_inventory.tag_number = params[:tag_number]
            new_inventory.details['old_inventory_id'] = old_inventory.id
            old_inventory.status = inventory_closed.original_code
            old_inventory.status_id = inventory_closed.id
            new_inventory.status_id = inventory_open.id
            new_inventory.status = inventory_open.original_code
            old_inventory.is_valid_inventory = false   
            old_inventory.save
            #Create New Record
            new_replacement = replacement.dup
            new_replacement.inventory = new_inventory
            new_replacement.rgp_number = params[:rgp_number] if params[:rgp_number].present?
            new_replacement.serial_number = params[:sr_number1]
            new_replacement.serial_number_2 = params[:sr_number2]
            new_replacement.replacement_date = params[:replacement_date].to_datetime
            new_replacement.replacement_remark = params[:replacement_remark]
            new_replacement.tag_number = new_inventory.tag_number
            if client_sku_master.present?
              new_replacement.client_sku_master_id = client_sku_master.id
              new_replacement.sku_code = client_sku_master.code
              new_replacement.item_description = client_sku_master.sku_description
              new_inventory.sku_code = client_sku_master.code
              new_inventory.item_description = client_sku_master.sku_description
              new_inventory.details['item_replaced_with_diffrent_item'] = true
            end
            new_inventory.save
            new_replacement.status_id = replacement_status.id
            new_replacement.status = replacement_status.original_code
            new_replacement.details['old_replacement_id'] = replacement.id
            replacement.status = closed_status.original_code
            replacement.status_id = closed_status.id
            replacement.is_active = false
            if new_replacement.save!
              replacement.save
              if params["files"].present?
                params["files"].each do |file|
                  new_replacement.replacement_attachments.create!(attachment_file: file, attachment_type: file_type.original_code, attachment_type_id: file_type.id)
                end
              end
              #Close Status of old replacement
              rh = replacement.replacement_histories.new(status_id: replacement.status_id)
              rh.details = {}
              key = "#{replacement.status.try(:downcase).try(:strip).split(' ').join('_')}_created_at"
              rh.details[key] = Time.now
              rh.details["status_changed_by_user_id"] = current_user.id
              rh.details["status_changed_by_user_name"] = current_user.full_name
              rh.save!
              #Create history of new replacemnt
              nrh = new_replacement.replacement_histories.new(status_id: new_replacement.status_id)
              nrh.details = {}
              key = "#{new_replacement.status.try(:downcase).try(:strip).split(' ').join('_')}_created_at"
              nrh.details[key] = Time.now
              nrh.details["status_changed_by_user_id"] = current_user.id
              nrh.details["status_changed_by_user_name"] = current_user.full_name
              nrh.save!
            end
          end
        rescue => error
          render json: {message: "#{error.message}", status: 302}
          return
        end
        get_replacements
        @replacements = @replacements.page(@current_page).per(@per_page)
        render json: @replacements
      else
        render json: {message: "Please provide Valid id", status: 302}
      end
    end
  end


  def get_dispositions
    lookup_key = LookupKey.find_by_code('WAREHOUSE_DISPOSITION')
    dispositions = lookup_key.lookup_values.where.not(original_code: ['Pending Disposition', 'Replacement', 'Pending Transfer Out', 'RTV']).order('original_code asc')
    policy_key = LookupKey.find_by_code('POLICY')
    policies = policy_key.lookup_values
    render json: {dispositions: dispositions.as_json(only: [:id, :original_code]), policies: policies.as_json(only: [:id, :original_code])}
  end

  def get_sku_records
    if params['sku'].present?
      client_sku_masters = ClientSkuMaster.find_by_code(params['sku'])
      render json: {client_sku_masters: client_sku_masters.as_json(only: [:id, :code, :sku_description])}
    else
      render json: {message: 'No Record Found For Given Value', status: 302}
    end
  end

  def set_disposition
    disposition = LookupValue.find_by_id(params[:disposition])
    file_type = LookupValue.find_by_code(Rails.application.credentials.replacement_file_type_replacement_disposition)
    @replacements = Replacement.includes(:inventory).where(id: params[:replacement_ids])
    policy = LookupValue.find_by_id(params['policy']) if params['policy'].present?
    if @replacements.present? && disposition.present?
      @replacements.each do |replacement|
        begin
          ActiveRecord::Base.transaction do
            inventory = replacement.inventory
            inventory.disposition = disposition.original_code
            replacement.details['disposition_set'] = true
            replacement.is_active = false
            replacement.disposition_remark = params[:desposition_remarks]
            if disposition.original_code == 'Liquidation'
              replacement.details['policy_id'] = policy.id
              replacement.details['policy_type'] = policy.original_code
              inventory.details['policy_id'] = policy.id
              inventory.details['policy_type'] = policy.original_code
            end

            replacement_status_closed = LookupValue.find_by_code(Rails.application.credentials.replacement_status_pending_replacement_closed)
            inventory.disposition = disposition.original_code
            replacement.status_id = replacement_status_closed.id
            replacement.status = replacement_status_closed.original_code

            if replacement.save!
              rh = replacement.replacement_histories.new(status_id: replacement.status_id)
              rh.details = {}
              key = "#{replacement.status.try(:downcase).try(:strip).split(' ').join('_')}_created_at"
              rh.details[key] = Time.now
              rh.details["status_changed_by_user_id"] = current_user.id
              rh.details["status_changed_by_user_name"] = current_user.full_name
              rh.save!
            end

            inventory.save
            DispositionRule.create_bucket_record(disposition.original_code, inventory, 'Replacement', current_user.id)
            if params["files"].present?
              params["files"].each do |file|
                replacement.replacement_attachments.create!(attachment_file: file, attachment_type: file_type.original_code, attachment_type_id: file_type.id)
              end
            end
          end
        rescue ActiveRecord::RecordInvalid => exception
          render json: "Something Went Wrong", status: :unprocessable_entity
          return
        end
      end
      get_replacements
      @replacements = @replacements.page(@current_page).per(@per_page)
      render json: @replacements
    else
      render json: "Please provide Valid Ids", status: :unprocessable_entity
    end
  end


  private

  def get_replacements
    set_pagination_params(params)
    get_distribution_centers
    ids = @distribution_center.present? ? [@distribution_center.id] : current_user.distribution_centers.pluck(:id)
    #if params['status'] == "Pending Replacement"
    #  status = ["Pending Replacement"]
    #else
    #  status = ["Pending Confirmation"]
    #end

    @replacements = Replacement.joins(:inventory).includes(:replacement_histories, :inventory, :replacement_attachments,inventory: :inventory_grading_details).where(distribution_center_id: ids, is_active: true, status: params['status']).order('replacements.created_at desc')
    # @replacements = @replacements.where("inventories.is_putaway_inwarded IS NOT false")
    #@replacements = @replacements.where.not(replacement_order_id: nil) if params['status'] == "Pending Replacement"
  end

  def filter_replacements
    @replacements = @replacements.where(tag_number: params[:tag_number].to_s.strip.split(',')) if params[:tag_number].present?
    @replacements = @replacements.where(sku_code: params[:article_id].to_s.strip.split(',')) if params[:article_id].present? 
    @replacements = @replacements.where("replacements.details ->> 'brand' in (?)", params[:brand].to_s.strip.split(',')) if params[:brand].present?
    @replacements = @replacements.where(vendor: params[:vendor_code].to_s.strip.split(',')) if params[:vendor_code].present? 
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

  def get_distribution_centers
    @distribution_center_ids = @distribution_center.present? ? [@distribution_center.id] : current_user.distribution_centers.ids
    @distribution_center_detail = ""
    if ["Default User", "Site Admin"].include?(current_user.roles.last.name)
      id = []
      if @distribution_center.present?
        ids = [@distribution_center.id]
      else
        ids = current_user.distribution_centers.ids
      end
      current_user.distribution_center_users.select(:id, :details).where(distribution_center_id: ids).each do |distribution_center_user|
        @distribution_center_detail = distribution_center_user.details.select{|d| d["disposition"] == "Replacement" || d["disposition"] == "All"}.last
        if @distribution_center_detail.present?
          @distribution_center_ids = @distribution_center_detail["warehouse"].include?(0) ? DistributionCenter.ids : @distribution_center_detail["warehouse"]
          return
        end
      end
    else
      @distribution_center_ids = @distribution_center.present? ? [@distribution_center.id] : DistributionCenter.ids
    end
  end

  #^ ------------ Dispatch Items Collection with filters -------------
  def get_dispatch_items
    set_pagination_params(params)
    warehouse_orders = WarehouseOrder.select(:id).where(orderable_type: "ReplacementOrder")
    return @warehouse_order_items if warehouse_orders.blank?
    if warehouse_orders.present?
      @warehouse_order_items = WarehouseOrderItem.where.not(tab_status: [:pending_disposition, :not_found_items]).where(warehouse_order_id: warehouse_orders.pluck(:id))&.order("updated_at desc")
    end
  end

  def get_dispatch_item
    @warehouse_order_item = WarehouseOrderItem.find(params[:id])
  end

  def dispatch_item_filters
    @warehouse_order_items = @warehouse_order_items.where(tag_number: params[:tag_number].to_s.strip.split(',')) if params[:tag_number].present?
    @warehouse_order_items = @warehouse_order_items.joins(:warehouse_order).where("warehouse_order_items.sku_master_code IN (?)", params[:article_id].to_s.strip.split(',')) if params[:article_id].present? 
    @warehouse_order_items = @warehouse_order_items.where("warehouse_order_items.details ->> 'brand' in (?)", params[:brand].to_s.strip.split(',')) if params[:brand].present?
    @warehouse_order_items = @warehouse_order_items.joins(:warehouse_order).where("warehouse_orders.vendor_code IN (?)", params[:vendor_code].to_s.strip.split(',')) if params[:vendor_code].present? 
  end

  def create_dispatch_items
    #& Step 1 -> Create Replacement Order
    create_replacement_order
    #& Step 2 -> Update Replacement Record
    update_status_for_replacements
    #& Step 3 -> Create Warehouse Order
    create_warehouse_order
    #& Step 4 -> Create Warehouse Order Items and create history
    create_warehouse_order_items
  end

  def create_replacement_order
    @replacement_order = ReplacementOrder.new(vendor_code: @replacements.first.vendor_code)
    @replacement_order.order_number = "OR-Replacement-#{SecureRandom.hex(6)}"
    @replacement_order.save!
  end

  def update_status_for_replacements
    @next_status = LookupValue.find_by(code: Rails.application.credentials.replacement_status_dispatch).original_code
    @next_status_id = LookupValue.find_by(original_code: @next_status).try(:id)
    @replacements.update_all(replacement_order_id: @replacement_order.id, status: @next_status, status_id: @next_status_id)
  end

  def create_warehouse_order
    @warehouse_order_status = LookupValue.find_by_code(Rails.application.credentials.dispatch_status_pending_pickup)
    @warehouse_order = @replacement_order.warehouse_orders.new(
      distribution_center_id: @replacements.first.distribution_center_id, 
      vendor_code: @replacement_order.vendor_code, 
      reference_number: @replacement_order.order_number,
      client_id: @replacements.last.client_id,
      status_id: @warehouse_order_status.id,
      total_quantity: @replacement_order.replacements.count
    )
    @warehouse_order.save!
  end

  def create_warehouse_order_items
    @replacement_order.replacements.each do |replacement|
      #& Creating replacement history
      replacement.create_history(current_user.id)
      #repair.update_inventory_status(@next_status)
      
      client_category = ClientSkuMaster.find_by_code(replacement.sku_code).client_category rescue nil
      @warehouse_order_item = @warehouse_order.warehouse_order_items.new(
        inventory_id: replacement.inventory_id,
        client_category_id: (client_category.id rescue nil),
        client_category_name: (client_category.name rescue nil),
        sku_master_code: replacement.sku_code,
        item_description: replacement.item_description,
        tag_number: replacement.tag_number,
        quantity: 1,
        status_id: @warehouse_order_status.id,
        status: @warehouse_order_status.original_code,
        serial_number: replacement.serial_number,
        aisle_location: replacement.aisle_location,
        toat_number: replacement.toat_number,
        details: replacement.inventory.details
      )
      @warehouse_order_item.save!
    end
  end

  # # TODO METHOD IN PROGRESS
  # def create_dispatch_items(object_ids)

  #   #& Validations
  #   raise CustomErrors.new "replacement_ids cannot be blank" if object_ids.blank?

  #   #& Find Replacements
  #   replacements = Replacement.where(id: object_ids)
  #   if replacements.present?
  #     begin
  #       ActiveRecord::Base.transaction do
          
  #         #& Initialize Replacement Order
  #         vendor_master = VendorMaster.find_by_vendor_code(params[:vendor_code])
  #         @replacement_order = ReplacementOrder.new(vendor_code: vendor_master.vendor_code)
  #         @replacement_order.order_number = "OR-Replacement-#{SecureRandom.hex(6)}"
          
  #         #& Storing Replacement Order
  #         if @replacement_order.save!
  #           #& Setting up Replacement Tab Status
  #           next_status = LookupValue.find_by(code: Rails.application.credentials.replacement_status_dispatch).original_code
  #           next_status_id = LookupValue.find_by(original_code: next_status).try(:id)
  #           #& Update Replacement record
  #           replacements.update_all(replacement_order_id: @replacement_order.id, status: next_status, status_id: next_status_id)
  #           #& Create Warehouse order
  #           warehouse_order_status = LookupValue.find_by_code(Rails.application.credentials.order_status_warehouse_pending_pick)
  #           warehouse_order = @replacements_order.warehouse_orders.new(distribution_center_id: replacements.first.distribution_center_id, vendor_code: replacements.first.vendor, reference_number: @replacement_order.order_number)
  #           warehouse_order.client_id = replacements.last.client_id
  #           warehouse_order.status_id = warehouse_order_status.id
  #           warehouse_order.total_quantity = @replacement_order.replacements.count
  #           warehouse_order.save!
  #           #& Create Warehouse Order Items
  #           @replacement_order.replacements.each do |replacement|
  #             client_category = ClientSkuMaster.find_by_code(replacement.sku_code).client_category rescue nil
  #             warehouse_order_item = warehouse_order.warehouse_order_items.new
  #             warehouse_order_item.inventory_id = replacement.inventory_id
  #             warehouse_order_item.client_category_id = client_category.id rescue nil
  #             warehouse_order_item.client_category_name = client_category.name rescue nil
  #             warehouse_order_item.sku_master_code = replacement.sku_code
  #             warehouse_order_item.item_description = replacement.item_description
  #             warehouse_order_item.tag_number = replacement.tag_number
  #             warehouse_order_item.quantity = 1
  #             warehouse_order_item.status_id = warehouse_order_status.id
  #             warehouse_order_item.serial_number = replacement.serial_number
  #             warehouse_order_item.aisle_location = replacement.aisle_location
  #             warehouse_order_item.toat_number = replacement.toat_number
  #             warehouse_order_item.details = replacement.inventory.details
  #             warehouse_order_item.save!
  #           end
  #         end
  #       end
  #     rescue ActiveRecord::RecordInvalid => exception
  #       render json: "Something Went Wrong", status: :unprocessable_entity
  #       return
  #     end
  #     render json: {order_number: @replacement_order.order_number}
  #   else
  #     render json: "Please provide Valid Replacement Id", status: :unprocessable_entity
  #   end
  # end

end
