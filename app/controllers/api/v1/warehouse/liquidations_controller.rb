class Api::V1::Warehouse::LiquidationsController < ApplicationController

  # skip_before_action :authenticate_user!
	# skip_before_action :check_permission
  skip_before_action :authenticate_user!, :check_permission, only: :republish_lots_callback
  before_action :check_for_republish_errors, :set_liquidation_order, only: %i(republish_lots_callback create_beam_republish_lots_async)
  before_action :lot_attachments, :clean_and_abort_the_republish_if_service_responded_with_error, only: :republish_lots_callback
  before_action :check_if_republish_already_in_progress, only: :create_beam_republish_lots_async

  def fetch_inventories
    set_pagination_params(params)
    get_distribution_centers
    ids = @distribution_center.present? ? [@distribution_center.id] : current_user.distribution_centers.pluck(:id)
    if params['status'] == 'Pending Lot Creation'
      status = [params['status'], 'Pending Liquidation Regrade', 'Pending RFQ']
      @liquidations = Liquidation.joins(:inventory).includes(:liquidation_order, :distribution_center, :inventory, :client_sku_master).where(distribution_center_id: ids, is_active: true, status: status)
      if current_user.roles.last.name == "Default User"
        @items = check_user_accessibility(@liquidations, @distribution_center_detail)
        @liquidations = @liquidations.where(id: @items.pluck(:id), assigned_disposition: nil).order('updated_at desc')
      end
    else
      @liquidations = Liquidation.joins(:inventory).includes(:liquidation_order, :distribution_center, :inventory, :client_sku_master).where(distribution_center_id: @distribution_center_ids, is_active: true, status: params['status']).order('liquidations.updated_at desc')
      # @items = check_user_accessibility(@inventories, @distribution_center_detail)
      # @inventories = @inventories.where(id: @items.pluck(:id)).page(@current_page).per(@per_page)
    end
    # @liquidations = @liquidations.where("inventories.is_putaway_inwarded IS NOT false")

    @liquidations = @liquidations.where("lower(liquidations.details ->> 'criticality') IN (?) ", params[:criticality]) if params['criticality'].present?
    @liquidations = @liquidations.page(@current_page).per(@per_page)
    render json: @liquidations, meta: pagination_meta(@liquidations)
  end

  def search_item
    set_pagination_params(params)
    get_distribution_centers
    ids = @distribution_center.present? ? [@distribution_center.id] : current_user.distribution_centers.pluck(:id)
    search_param = params['search'].split(',').collect(&:strip).flatten
    if params['search_in'] == 'brand'
       @liquidations = Liquidation.joins(:inventory).includes(:liquidation_order, :distribution_center, :liquidation_request).where(status: params['status'], is_active: true, distribution_center_id: ids).where("lower(liquidations.details ->> 'brand') IN (?) ", search_param.map(&:downcase))
    elsif params['search_in'] == 'request_number'
      status = [params['status'], 'Pending Liquidation Regrade', 'Pending RFQ']
      liq_requests = LiquidationRequest.where(request_id: search_param.map(&:downcase))
      if liq_requests.present?
        @liquidations = Liquidation.joins(:inventory).includes(:liquidation_order, :distribution_center, :liquidation_request).where(status: status, is_active: true, distribution_center_id: ids).where(liquidation_request_id: liq_requests.pluck(:id))
      else
        @liquidations = []
      end
    else
      status = (params['status'] == 'Pending Lot Creation') ? [params['status'], 'Pending Liquidation Regrade', 'Pending RFQ'] : [params['status']]
      @liquidations = Liquidation.joins(:inventory).includes(:liquidation_order, :distribution_center, :liquidation_request).where(status: status, is_active: true, distribution_center_id: ids).where("lower(liquidations.#{params['search_in']}) IN (?) ", search_param.map(&:downcase))
    end
    # @liquidations = @liquidations.where("inventories.is_putaway_inwarded IS NOT false")
    @liquidations = @liquidations.where("lower(liquidations.details ->> 'criticality') IN (?) ", param[:criticality].map(&:downcase)) if params['criticality'].present?
    @liquidations = @liquidations.page(@current_page).per(@per_page)
    render json: @liquidations, meta: pagination_meta(@liquidations)
  end

  def fetch_beam_inventories
    lot_type = LookupValue.find_by(code: Rails.application.credentials.liquidation_lot_type_beam_lot)
    @inventories = Liquidation.where(distribution_center_id: current_user.distribution_centers, is_active: true, lot_type_id: lot_type.id).order(created_at: :desc)
    render json: @inventories
  end

  def get_liquidation_images
    @inventories = Liquidation.where(id: params[:id])
    @images = []
    @inventories.each do |liquidation|
      liquidation.inventory.inventory_grading_details.each do |detail|
        if detail.details["final_grading_result"].present? && detail.details["final_grading_result"]["Physical Condition"].present?
          (detail.details["final_grading_result"]["Physical Condition"] rescue []).each do |t|
            @images << t["annotations"].map{|x| x["src"]} rescue []
          end
        end

        if detail.details["final_grading_result"].present? && detail.details["final_grading_result"]["Item Condition"].present?
          (detail.details["final_grading_result"]["Item Condition"] rescue []).each do |t|
            @images << t["annotations"].map{|x| x["src"]} rescue []
          end
        end
      end
    end
    if @images.flatten.blank?
      render json: ""
    else
      render json: @images.flatten
    end
  end

  def remove_excess_items_before_dispatch
    tags = params["tag_numbers"]
    liquidations = Liquidation.where(tag_number: tags)
    if liquidations.present?
      liquidation_order = LiquidationOrder.find(params[:id])
      liquidation_order.details['removed_tags'] = liquidation_order.details['removed_tags'] || []
      liquidation_order.details['removed_tags'] << liquidations.pluck(:tag_number).flatten
      liquidation_order.details['items_deleted'] = true
      liquidation_order.tags = liquidation_order.tags - liquidations.pluck(:tag_number).flatten
      order_items = WarehouseOrderItem.where(tag_number: tags)
      liquidation_pending_status = LookupValue.where(code:Rails.application.credentials.liquidation_pending_status).first
      liquidations.each do |liquidation|
        lot = liquidation.liquidation_order
        next unless lot
        lot.quantity = lot.quantity - 1
        lot.save
        liquidation.is_active = true
        liquidation.liquidation_order_id =  nil
        liquidation.lot_name =  nil
        liquidation.status = liquidation_pending_status.original_code
        liquidation.status_id = liquidation_pending_status.id
        liquidation.details["reason_for_not_dispatch"] = params["reason"]
        liquidation.details["remark_for_not_dispatch"] = params["remark"] if params["remark"].present?
        liquidation.details["removed_by_user_id"] = current_user.id
        liquidation.details["removed_by_user_name"] = current_user.full_name
        if liquidation.save
          details = current_user.present? ? { status_changed_by_user_id: current_user.id, status_changed_by_user_name: current_user.full_name } : {}
          LiquidationHistory.create(
            liquidation_id: liquidation.id, status_id: liquidation.status_id, status: liquidation.status,
            created_at: Time.now, updated_at: Time.now, details: details
          )
        end
      end
      liquidation_order.save
      if params['new_lot_name'].present?
        @liquidation_order_new = liquidation_order.dup
        @liquidation_order_new.lot_name = params['new_lot_name']
        @liquidation_order_new.quantity = @liquidation_order_new.quantity - liquidations.size
        if @liquidation_order_new.save
          liquidation_order.liquidations.update_all(lot_name: @liquidation_order_new.lot_name, liquidation_order_id: @liquidation_order_new.id)
          liquidation_order.delete
        end
      end

      if order_items.present?
        order_items.each do |item|
          if item.warehouse_order.present?
            order = item.warehouse_order
            order.total_quantity = order.total_quantity - 1
            order.save
            order.delete if order.total_quantity == 0 
          end
          if item.details == nil
            item.details = {}
          end
          item.details["reason_for_not_dispatch"] = params["reason"]
          item.details["remark_for_not_dispatch"] = params["remark"] if params["remark"].present?
          item.details["removed_by_user_id"] = current_user.id
          item.details["removed_by_user_name"] = current_user.full_name
          item.save
          item.delete
        end
      end
      render json: (@liquidation_order_new.present? ? @liquidation_order_new : liquidation_order) 
    else
      render json: { errors: "No Data Present" }, status: 500
    end
  end

  def get_liquidation_images_page
    if ["b2b_email", "b2b_auction"].include?(params[:request_type])
      @inventories = Liquidation.includes(inventory: [:inventory_grading_details]).where(id: JSON.parse(params[:id])) rescue []
    elsif params[:request_type] == "republish_lot"
      @inventories = LiquidationOrder.includes(:liquidations => [:inventory => [:inventory_grading_details]]).find(JSON.parse(params[:id]).first).liquidations rescue []
    elsif params[:request_type] == "edit_lot" || params[:request_type] == "edit_email_lot"
      lot = LiquidationOrder.includes(:liquidations => [:inventory => [:inventory_grading_details]]).find(JSON.parse(params[:id]).first)
      lot_images = lot.lot_image_urls.uniq
      all_images = []
      lot.liquidations.each do |l|
        l.inventory.inventory_grading_details.each do |detail|
          if (detail.details["final_grading_result"].present?) && (detail.details["final_grading_result"]["Physical Condition"].present?)
            (detail.details["final_grading_result"]["Physical Condition"] rescue []).each do |t|
              all_images << t["annotations"].map{|x| x["src"]} rescue []
            end
          end

          if detail.details["final_grading_result"].present? && detail.details["final_grading_result"]["Item Condition"].present?
            (detail.details["final_grading_result"]["Item Condition"] rescue []).each do |t|
              all_images << t["annotations"].map{|x| x["src"]} rescue []
            end
          end
        end
      end
      unselected_images = (all_images.flatten - lot_images).flatten.compact.uniq
      @images = unselected_images
    end

    if ["b2b_email", "b2b_auction", "republish_lot"].include?(params[:request_type])
      @images = []
      if @inventories.present?
        @inventories.each do |liquidation|
          liquidation.inventory.inventory_grading_details.each do |detail|
            if (detail.details["final_grading_result"]["Physical Condition"].present? rescue false)
              (detail.details["final_grading_result"]["Physical Condition"] rescue []).each do |t|
                @images << t["annotations"].map{|x| x["src"]} rescue []
              end
            end
            if (detail.details["final_grading_result"]["Item Condition"].present? rescue false)
              (detail.details["final_grading_result"]["Item Condition"] rescue []).each do |t|
                @images << t["annotations"].map{|x| x["src"]} rescue []
              end
            end
          end
        end
      end
    end
    if @images.flatten.blank?
      render json: ""
    else
      @paginated_images = Kaminari.paginate_array(@images.flatten.uniq).page(params[:page]).per(16)
      render json: @paginated_images , root: "Images"
    end
  end


  def get_republish_liquidation_images
    @inventories = LiquidationOrder.find(params[:id]).liquidations
    @images = []
    @inventories.each do |liquidation|
      liquidation.inventory.inventory_grading_details.each do |detail|
        if detail.details["final_grading_result"].present? && detail.details["final_grading_result"]["Physical Condition"].present?
          (detail.details["final_grading_result"]["Physical Condition"] rescue []).each do |t|
            @images << t["annotations"].map{|x| x["src"]} rescue []
          end
        end

        if detail.details["final_grading_result"].present? && detail.details["final_grading_result"]["Item Condition"].present?
          (detail.details["final_grading_result"]["Item Condition"] rescue []).each do |t|
            @images << t["annotations"].map{|x| x["src"]} rescue []
          end
        end
      end
    end
    render json: @images.flatten
  end

  def generate_csv
    # LiquidationInventoriesWorker.perform_async(current_user.id)     
    # render json: "success"  
    # url = Liquidation.export(current_user.id)  
    # render json: {url: url}
    type = "liquidation_download"
    liq_ids = params["liq_ids"].present? ? params["liq_ids"].to_json : nil
    ReportMailerWorker.perform_async(type, current_user.id, nil, nil, params["email"], liq_ids)
    render json: "success"
  end

  def get_vendor_liquidation
    @vendor_master = VendorMaster.joins(:vendor_types).where('vendor_types.vendor_type': 'Email Liquidation').distinct
    render json: @vendor_master
  end

  def search_vendor
    search_param = params['search'].split(',').collect(&:strip).flatten
    @vendor_master = VendorMaster.joins(:vendor_types).where('vendor_types.vendor_type': 'Email Liquidation').where("lower(#{params['search_in']}) IN (?) ", search_param.map(&:downcase)).distinct
    render json: @vendor_master
  end

  def get_vendor_contract
    @vendor_master = VendorMaster.joins(:vendor_types).where('vendor_types.vendor_type': 'Contracted Liquidation').distinct
    render json: @vendor_master
  end

  def create_lots
    # Liquidation.import_lots(params[:file])
    lot_type = LookupValue.find_by(code: Rails.application.credentials.liquidation_lot_type_email_lot)
    lot_status = LookupValue.find_by(code:Rails.application.credentials.lot_status_pending_closure)

    # new_liquidation_status = LookupValue.where(code: Rails.application.credentials.liquidation_pending_lot_dispatch_status).first
    image_urls = params[:images].present? ? JSON.parse(params[:images]) : ''
    liquidation_order = LiquidationOrder.new(lot_name: params[:lot_name], lot_desc: params[:lot_desc], mrp: params[:lot_mrp], end_date: params[:end_date], start_date: params[:start_date], status:lot_status.original_code, status_id: lot_status.id, order_amount: params[:lot_expected_price], quantity:params[:liquidation_obj].count, lot_type: lot_type.original_code, lot_type_id: lot_type.id, lot_image_urls: image_urls)

    if liquidation_order.save
      if params[:files].present?
        params[:files].each do |file|
          attach = liquidation_order.lot_attachments.new(attachment_file: file)
          attach.save!
        end
        liquidation_order.lot_image_urls = liquidation_order.lot_attachments.map(&:attachment_file_url) 
        liquidation_order.save
      end
   
      # warehouse_order = WarehouseOrder.create( orderable: liquidation_order, total_quantity: liquidation_order.order_amount, distribution_center_id:Liquidation.find( params[:liquidation_obj].first).distribution_center_id, status_id:LookupValue.find_by(code:Rails.application.credentials.order_status_warehouse_pending_pick).id)
      
      liquidation_order_history = LiquidationOrderHistory.create(liquidation_order_id:liquidation_order.id, status: lot_status.original_code, status_id: lot_status.id, details: {"Pending_Closure_created_date" => Time.now.to_s } ) 

      original_code, status_id = LookupStatusService.new('Liquidation', 'create_lots').call
      Liquidation.includes(:liquidation_request).where(id: params[:liquidation_obj]).each do |liquidation_item|
        request = liquidation_item.liquidation_request
        liquidation_item.update( lot_name: params[:lot_name], liquidation_order_id: liquidation_order.id , status: original_code , status_id: status_id, lot_type: lot_type.original_code, lot_type_id: lot_type.id )
        request.update(total_items: (request.total_items - 1), graded_items: (request.graded_items - 1)) if request.present?
        liquidation_item.liquidation_histories.create( 
          status_id: status_id, 
          status: original_code,
          details: {"status_changed_by_user_id" => current_user.id, "status_changed_by_user_name" => current_user.full_name } )
        # client_sku_master = ClientSkuMaster.find_by_code(liquidation_item.sku_code)  rescue nil
        # client_category = client_sku_master.client_category rescue nil
        # WarehouseOrderItem.create( warehouse_order_id:warehouse_order.id , inventory_id: liquidation_item.inventory_id , client_category_id: client_category.try(:id) , client_category_name: client_category.try(:name) , sku_master_code: client_sku_master.try(:code) , item_description: liquidation_item.item_description , tag_number: liquidation_item.tag_number , serial_number: liquidation_item.sr_number , quantity: liquidation_item.sales_price , status_id:LookupValue.find_by(code:Rails.application.credentials.order_status_warehouse_pending_pick).id, status: LookupValue.find_by(code:Rails.application.credentials.order_status_warehouse_pending_pick).original_code)
      end
      liquidation_order.update(tags: liquidation_order.liquidations.pluck(:tag_number))

        render json: "success" 
    else
      render json: { errors: liquidation_order.errors.full_messages.join(',').to_s }, status: 500
    end
  end

  def create_manual_dispatch_lot
    distribution_center = Liquidation.find(params[:liquidation_obj][0]).distribution_center
    lot_type = LookupValue.find_by(code: 'liquidation_lot_type_manual_dispatch_lot')
    lot_status = LookupValue.find_by(code:Rails.application.credentials.lot_status_pending_closure)
    new_liquidation_status = LookupValue.where(code: Rails.application.credentials.liquidation_pending_lot_dispatch_status).first
    liquidation_order = LiquidationOrder.new(lot_name: "#{distribution_center.code}-Offline Lot-#{LiquidationOrder.with_deleted.last.id + 1}", lot_desc: "#{distribution_center.code}-Offline Lot-#{LiquidationOrder.with_deleted.last.id + 1}", mrp: 0, end_date: Date.today.to_datetime, start_date: Date.today.to_datetime, status:lot_status.original_code, status_id: lot_status.id, order_amount: 0, quantity: params[:liquidation_obj].count,
                          lot_type: lot_type.original_code, lot_type_id: lot_type.id, floor_price: 0.0, reserve_price: 0.0, buy_now_price: 0.0, increment_slab: 0)
    if liquidation_order.save  
      liquidation_order_history = LiquidationOrderHistory.create(liquidation_order_id:liquidation_order.id, status: lot_status.original_code, status_id: lot_status.id, details: {"Pending_Closure_created_date" => Time.now.to_s } ) 

      params[:liquidation_obj].each do |i|

        liquidation_item = Liquidation.find(i)
        request = liquidation_item.liquidation_request
        liquidation_item.update( lot_name: liquidation_order.lot_name, liquidation_order_id: liquidation_order.id , status: new_liquidation_status.original_code , status_id: new_liquidation_status.id, lot_type: lot_type.original_code, lot_type_id: lot_type.id )
        request.update(total_items: (request.total_items - 1), graded_items: (request.graded_items - 1)) if request.present?
        LiquidationHistory.create(
          liquidation_id: liquidation_item.id , 
          status_id: new_liquidation_status.try(:id), 
          status: new_liquidation_status.try(:original_code),
          details: {"status_changed_by_user_id" => current_user.id, "status_changed_by_user_name" => current_user.full_name } )
      end

        render json: "success" 
    else
      render json: { errors: liquidation_order.errors.full_messages.join(',').to_s }, status: 500
    end
  end

  def create_beam_lots
    lot_type = LookupValue.find_by(code: Rails.application.credentials.liquidation_lot_type_beam_lot)
    lot_status = LookupValue.find_by(code: Rails.application.credentials.lot_status_pending_publish)
    original_code, status_id = LookupStatusService.new('Liquidation', 'create_beam_lots').call

    liquidation_order = LiquidationOrder.new(lot_name: params[:lot_name], lot_desc: params[:lot_desc], mrp: params[:lot_mrp], end_date: params[:end_date], start_date: params[:start_date], status:lot_status.original_code, status_id: lot_status.id, order_amount: params[:lot_expected_price], quantity:params[:liquidation_obj].count,
                          lot_type: lot_type.original_code, lot_type_id: lot_type.id, floor_price: params[:floor_price].to_f, reserve_price: params[:reserve_price].to_f, buy_now_price: params[:buy_now_price].to_f, increment_slab: params[:increment_slab].to_i, lot_image_urls: JSON.parse(params[:images]))

    if liquidation_order.save
      if params[:files].present?
        params[:files].each do |file|
          attach = liquidation_order.lot_attachments.new(attachment_file: file)
          attach.save!
        end
        lot_images = (liquidation_order.lot_image_urls += liquidation_order.lot_attachments.map(&:attachment_file_url)).flatten.compact.uniq
        liquidation_order.update(lot_image_urls: lot_images.flatten)
      end


      liquidation_order_history = LiquidationOrderHistory.create(liquidation_order_id:liquidation_order.id, status: lot_status.original_code, status_id: lot_status.id)
      params[:liquidation_obj].each do |i|
        liquidation_item = Liquidation.find(i)
        request = liquidation_item.liquidation_request
        liquidation_item.update( lot_name: params[:lot_name], liquidation_order_id: liquidation_order.id , status: original_code , status_id: status_id, lot_type: lot_type.original_code, lot_type_id: lot_type.id)
        request.update(total_items: (request.total_items - 1), graded_items: (request.graded_items - 1)) if request.present?
        LiquidationHistory.create(
          liquidation_id: liquidation_item.id , 
          status_id: status_id, 
          status: original_code,
          details: {"status_changed_by_user_id" => current_user.id, "status_changed_by_user_name" => current_user.full_name } )
      end
      liquidation_order.update(tags: liquidation_order.liquidations.pluck(:tag_number))
      render json: "success" 
    else
      render json: { errors: liquidation_order.errors.full_messages.join(',').to_s }, status: 500
    end
  end

  def create_beam_republish_lots_async
    worker_params = republish_params.merge!({ lot_attachment_ids: lot_attachment_ids, bidding_method: current_user.bidding_method, current_user: current_user })
    @old_liquidation_order.update(republish_status: 'pending')
    RepublishWorker.perform_async(worker_params.to_h)
    render json: { message:  "Initiated Republish", republish_status: "pending" }, status: :ok
  end

  def create_beam_republish_lots
    begin
      ActiveRecord::Base.transaction do
        # create new liquidation order for republish starts
        lot_type = LookupValue.find_by(code: Rails.application.credentials.liquidation_lot_type_beam_lot)
        lot_status = LookupValue.find_by(code: Rails.application.credentials.lot_status_in_progress)
        new_liquidation_status = LookupValue.where(code: Rails.application.credentials.liquidation_pending_lot_dispatch_status).first

        old_liquidation_order = LiquidationOrder.find(params[:id])
        archived_status = LookupValue.find_by(code: Rails.application.credentials.lot_status_archived)
        old_liquidation_order.update(status: archived_status.original_code, status_id: archived_status.id)
        liquidation_items = old_liquidation_order.liquidations
        liquidation_order = LiquidationOrder.create(lot_name: params[:lot_name], lot_desc: params[:lot_desc], mrp: params[:lot_mrp], end_date: params[:end_date], start_date: params[:start_date], status:lot_status.original_code, status_id: lot_status.id, order_amount: params[:lot_expected_price], quantity:liquidation_items.count, lot_type: lot_type.original_code, lot_type_id: lot_type.id, floor_price: params[:floor_price].to_f, reserve_price: params[:reserve_price].to_f, buy_now_price: params[:buy_now_price].to_f, increment_slab: params[:increment_slab].to_i, lot_image_urls: JSON.parse(params[:images]), details: old_liquidation_order.details)

        if params[:files].present?
          params[:files].each do |file|
            attach = liquidation_order.lot_attachments.new(attachment_file: file)
            attach.save!
          end
          lot_images = (liquidation_order.lot_image_urls += liquidation_order.lot_attachments.map(&:attachment_file_url)).flatten.compact.uniq
          liquidation_order.update(lot_image_urls: lot_images.flatten)
        end

        liquidation_order_history = LiquidationOrderHistory.create(liquidation_order_id:liquidation_order.id, status: lot_status.original_code, status_id: lot_status.id)
        old_liquidation_order.update_liquidation_status('update_lot_beam_status', current_user, liquidation_order.id, {lot_name: params[:lot_name], lot_type: lot_type.original_code, lot_type_id: lot_type.id })
        # create new liquidation order for republish ends
        # publish new liquidation to beam starts
        response = liquidation_order.republish_to_beam(old_liquidation_order.lot_name, current_user)
        parsed_response = JSON.parse(response)
        if parsed_response.present? && parsed_response["status"] == 500
          render json: { errors: parsed_response["errors"] }, status: 500
          raise ActiveRecord::Rollback
        else
          render json: "success"
        end
        # publish new liquidation to beam ends
      end # transaction end
    rescue Exception => message
      render json: { errors: message.to_s }, status: 500
    end # rescue end
  end

  def republish_lots_callback
    ActiveRecord::Base.transaction do
      lot_type = LookupValue.find_by(code: Rails.application.credentials.liquidation_lot_type_beam_lot)
      lot_status = LookupValue.find_by(code: Rails.application.credentials.lot_status_in_progress)
      new_liquidation_status = LookupValue.where(code: Rails.application.credentials.liquidation_pending_lot_dispatch_status).first
      archived_status = LookupValue.find_by(code: Rails.application.credentials.lot_status_archived)
      @old_liquidation_order.update(status: archived_status.original_code, status_id: archived_status.id)
      liquidation_items = @old_liquidation_order.liquidations
      liquidation_order = LiquidationOrder.create(
                            lot_name: republish_params[:lot_name],
                            lot_desc: republish_params[:lot_desc],
                            mrp: republish_params[:lot_mrp],
                            end_date: republish_params[:end_date],
                            start_date: republish_params[:start_date],
                            status: lot_status.original_code,
                            status_id: lot_status.id,
                            order_amount: republish_params[:lot_expected_price],
                            quantity:liquidation_items.count,
                            lot_type: lot_type.original_code,
                            lot_type_id: lot_type.id,
                            floor_price: republish_params[:floor_price].to_f,
                            reserve_price: republish_params[:reserve_price].to_f,
                            buy_now_price: republish_params[:buy_now_price].to_f,
                            increment_slab: republish_params[:increment_slab].to_i,
                            lot_image_urls: JSON.parse(republish_params[:images]),
                            beam_lot_id: republish_params[:new_bid_master_id]
                          )
      if @lot_attachments.present?
        liquidation_order.lot_attachments << @lot_attachments
        lot_images = (liquidation_order.lot_image_urls += @lot_attachments.map(&:attachment_file_url)).flatten.compact.uniq
        liquidation_order.update(lot_image_urls: lot_images )
      end
      LiquidationOrderHistory.create(liquidation_order_id: liquidation_order.id, status: lot_status.original_code, status_id: lot_status.id)
      @old_liquidation_order.update_liquidation_status('update_lot_beam_status', current_user, liquidation_order.id, { lot_name: republish_params[:lot_name], lot_type: lot_type.original_code, lot_type_id: lot_type.id })
      @old_liquidation_order.update(republish_status: 'success')
      render json: { message: "Successfully Republished on BEAM", lot_name: liquidation_order.lot_name }, status: :ok
    end
  rescue Exception => message
    render_error message
  end

  def create_contract_lots
    lot_type = LookupValue.find_by(code: "liquidation_lot_type_contract_lot")
    lot_status = LookupValue.find_by(code: Rails.application.credentials.lot_status_pending_publish)
    original_code, status_id = LookupStatusService.new('Liquidation', 'create_beam_lots').call
    liquidation_order = LiquidationOrder.new(lot_name: params[:lot_name], lot_desc: params[:lot_desc], status: lot_status.original_code, status_id: lot_status.id, quantity: params[:liquidation_obj].count, lot_type: lot_type.original_code, lot_type_id: lot_type.id)
    if liquidation_order.save
      if params[:files].present?
        params[:files].each do |file|
          attach = liquidation_order.lot_attachments.new(attachment_file: file)
          attach.save!
        end
        lot_images = (liquidation_order.lot_image_urls += liquidation_order.lot_attachments.map(&:attachment_file_url)).flatten.compact.uniq
        liquidation_order.update(lot_image_urls: lot_images.flatten)
      end
      liquidation_order_history = LiquidationOrderHistory.create(liquidation_order_id:liquidation_order.id, status: lot_status.original_code, status_id: lot_status.id)
      params[:liquidation_obj].each do |i|
        liquidation_item = Liquidation.find(i)
        request = liquidation_item.liquidation_request
        liquidation_item.update(lot_name: params[:lot_name], liquidation_order_id: liquidation_order.id, status: original_code, status_id: status_id, lot_type: lot_type.original_code, lot_type_id: lot_type.id)
        request.update(total_items: (request.total_items - 1), graded_items: (request.graded_items - 1)) if request.present?
        LiquidationHistory.create(liquidation_id: liquidation_item.id, status_id: status_id, status: original_code, details: {"status_changed_by_user_id" => current_user.id, "status_changed_by_user_name" => current_user.full_name})
      end
      liquidation_order.update(tags: liquidation_order.liquidations.pluck(:tag_number))
      render json: "success"
    else
      render json: { errors: liquidation_order.errors.full_messages.join(',').to_s }, status: 500
    end
  end

  def update_lot_order
    order_status_warehouse_pending_pick = LookupValue.find_by(code:Rails.application.credentials.order_status_warehouse_pending_pick)
    @liquidation_order = LiquidationOrder.includes(liquidations: :client_sku_master).find(params[:id])
    if params[:lot_status] == "Partial Payment"
      @liquidation_order.status =   LookupValue.find_by(code:Rails.application.credentials.lot_status_partial_payment).original_code
      @liquidation_order.status_id =  LookupValue.find_by(code:Rails.application.credentials.lot_status_partial_payment).id
      liquidation_order_history = LiquidationOrderHistory.create(liquidation_order_id:@liquidation_order.id, status: @liquidation_order.status, status_id: @liquidation_order.status_id, details: {"Partial_Payment_created_date" => Time.now.to_s } ) 
    elsif params[:lot_status] == "Full Payment Received"
      @liquidation_order.status =  LookupValue.find_by(code:Rails.application.credentials.lot_status_full_payment_received).original_code
      @liquidation_order.status_id = LookupValue.find_by(code:Rails.application.credentials.lot_status_full_payment_received).id
      liquidation_order_history = LiquidationOrderHistory.create(liquidation_order_id:@liquidation_order.id, status: @liquidation_order.status, status_id: @liquidation_order.status_id, details: {"Full_Payment_Received_created_date" => Time.now.to_s } ) 
    elsif params[:lot_status] == "Dispatch Ready"
      @liquidation_order.status = LookupValue.find_by(code:Rails.application.credentials.lot_status_dispatch_ready).original_code
      @liquidation_order.status_id =  LookupValue.find_by(code:Rails.application.credentials.lot_status_dispatch_ready).id
      liquidation_order_history = LiquidationOrderHistory.create(liquidation_order_id:@liquidation_order.id, status: @liquidation_order.status, status_id: @liquidation_order.status_id, details: {"Dispatch_Ready_created_date" => Time.now.to_s } ) 
    end  

    @liquidation_order.winner_code = params[:winner_code]
    @liquidation_order.winner_amount = params[:winner_amount]
    @liquidation_order.payment_status =  params[:payment_status] 
    @liquidation_order.amount_received = params[:amount_received]
    @liquidation_order.dispatch_ready = params[:dispatch_status]
    @liquidation_order.details['winner_amount_update_reason'] = params[:amount_change_reason] if params[:amount_change_reason].present?

    if @liquidation_order.save
      if params[:dispatch_status] == "true"
          @liquidation_item_list = @liquidation_order.liquidations  
          warehouse_order = @liquidation_order.warehouse_orders.create( 
            orderable:  @liquidation_order, 
            vendor_code: params[:winner_code], 
            total_quantity:  @liquidation_item_list.count, 
            client_id: @liquidation_item_list.last.client_id,
            reference_number: @liquidation_order.order_number,
            distribution_center_id: @liquidation_item_list.first.distribution_center_id, 
            status_id: order_status_warehouse_pending_pick.id)    
          
          @liquidation_item_list.each do |liquidation_item|
            original_code, status_id = LookupStatusService.new("Dispatch", "pending_pick_and_pack").call
            liquidation_item.update(status: original_code, status_id: status_id)
            details = { "#{liquidation_item.status.try(:downcase).try(:strip).split(' ').join('_')}_created_at" => Time.now,
              "status_changed_by_user_id" => current_user.id,
              "status_changed_by_user_name" => current_user.full_name,
            }
            liquidation_item.liquidation_histories.create(status_id: liquidation_item.status_id, details: details)

            client_sku_master = liquidation_item.client_sku_master  rescue nil
            client_category = client_sku_master.client_category rescue nil

            WarehouseOrderItem.create( warehouse_order_id:warehouse_order.id , 
              inventory_id: liquidation_item.inventory_id , 
              client_category_id: client_category.try(:id) , 
              client_category_name: client_category.try(:name) , 
              sku_master_code: client_sku_master.try(:code) , 
              item_description: liquidation_item.item_description , 
              tag_number: liquidation_item.tag_number , 
              serial_number: liquidation_item.inventory.serial_number , 
              quantity: liquidation_item.sales_price , 
              status_id: order_status_warehouse_pending_pick.id, 
              status: order_status_warehouse_pending_pick.original_code )
          end
          if params[:files].present?
            params[:files].each do |file|
              attach = @liquidation_order.lot_attachments.new(attachment_file: file)
              attach.save!
            end
          end
        end
      render json: @liquidation_order
    else
      render json: @liquidation_order.errors, status: :unprocessable_entity
    end

  end

  def dispatch_offline_lot
    liquidation_order = LiquidationOrder.find_by(id: params[:id])
    liquidation_order.status = LookupValue.find_by(code:Rails.application.credentials.lot_status_dispatch_ready).original_code
    liquidation_order.status_id =  LookupValue.find_by(code:Rails.application.credentials.lot_status_dispatch_ready).id
    liquidation_order_history = LiquidationOrderHistory.create(liquidation_order_id: liquidation_order.id, status: liquidation_order.status, status_id: liquidation_order.status_id, details: {"Dispatch_Ready_created_date" => Time.now.to_s } )
    liquidation_order.vendor_code = params[:winner_user]
    ActiveRecord::Base.transaction do
      if liquidation_order.save

        liquidation_item_list = liquidation_order.liquidations  
        warehouse_order = liquidation_order.warehouse_orders.create( 
          orderable:  liquidation_order, 
          vendor_code: params[:winner_user],
          total_quantity:  liquidation_item_list.count, 
          client_id: liquidation_item_list.last.client_id,
          reference_number: liquidation_order.order_number,
          distribution_center_id: liquidation_item_list.first.distribution_center_id, 
          status_id:LookupValue.find_by(code:Rails.application.credentials.order_status_warehouse_pending_pick).id)    

        liquidation_item_list.each do |liquidation_item|
          original_code, status_id = LookupStatusService.new("Dispatch", "pending_pick_and_pack").call
          liquidation_item.update(status: original_code, status_id: status_id)
          details = { "#{liquidation_item.status.try(:downcase).try(:strip).split(' ').join('_')}_created_at" => Time.now,
            "status_changed_by_user_id" => current_user.id,
            "status_changed_by_user_name" => current_user.full_name,
          }
          liquidation_item.liquidation_histories.create(status_id: liquidation_item.status_id, details: details)

          client_sku_master = ClientSkuMaster.find_by_code(liquidation_item.sku_code)  rescue nil
          client_category = client_sku_master.client_category rescue nil

          WarehouseOrderItem.create( warehouse_order_id:warehouse_order.id , 
            inventory_id: liquidation_item.inventory_id , 
            client_category_id: client_category.try(:id) , 
            client_category_name: client_category.try(:name) , 
            sku_master_code: client_sku_master.try(:code) , 
            item_description: liquidation_item.item_description , 
            tag_number: liquidation_item.tag_number , 
            serial_number: liquidation_item.inventory.serial_number , 
            quantity: liquidation_item.sales_price , 
            status_id:LookupValue.find_by(code:Rails.application.credentials.order_status_warehouse_pending_pick).id, 
            status: LookupValue.find_by(code:Rails.application.credentials.order_status_warehouse_pending_pick).original_code)
        end
        render json: liquidation_order
      else
        render json: liquidation_order.errors, status: :unprocessable_entity
      end
    end
  end

  def update_lot_winner
    @liquidation_order = LiquidationOrder.find(params[:id])
    if params[:lot_status] == "Partial Payment"
      @liquidation_order.status =   LookupValue.find_by(code:Rails.application.credentials.lot_status_partial_payment).original_code
      @liquidation_order.status_id =  LookupValue.find_by(code:Rails.application.credentials.lot_status_partial_payment).id
      liquidation_order_history = LiquidationOrderHistory.create(liquidation_order_id:@liquidation_order.id, status: @liquidation_order.status, status_id: @liquidation_order.status_id, details: {"Partial_Payment_created_date" => Time.now.to_s } ) 
    elsif params[:lot_status] == "Full Payment Received"      
      @liquidation_order.status =  LookupValue.find_by(code:Rails.application.credentials.lot_status_full_payment_received).original_code
      @liquidation_order.status_id = LookupValue.find_by(code:Rails.application.credentials.lot_status_full_payment_received).id
      liquidation_order_history = LiquidationOrderHistory.create(liquidation_order_id:@liquidation_order.id, status: @liquidation_order.status, status_id: @liquidation_order.status_id, details: {"Full_Payment_Received_created_date" => Time.now.to_s } ) 
    elsif params[:lot_status] == "Dispatch Ready"
      @liquidation_order.status = LookupValue.find_by(code:Rails.application.credentials.lot_status_dispatch_ready).original_code
      @liquidation_order.status_id =  LookupValue.find_by(code:Rails.application.credentials.lot_status_dispatch_ready).id
      liquidation_order_history = LiquidationOrderHistory.create(liquidation_order_id:@liquidation_order.id, status: @liquidation_order.status, status_id: @liquidation_order.status_id, details: {"Dispatch_Ready_created_date" => Time.now.to_s } ) 
    end  

    @liquidation_order.winner_code = params[:winner_user]
    @liquidation_order.vendor_code = params[:winner_user]
    @liquidation_order.winner_amount = params[:winner_price]
    @liquidation_order.payment_status =  params[:winner_payment_status] 
    @liquidation_order.amount_received = params[:winner_amount_received]
    @liquidation_order.dispatch_ready = params[:winner_dispatch_status]
    @liquidation_order.remarks = params[:winner_remarks]

    if params["winner_billing_to"].present?
      record = VendorMaster.find(params["winner_billing_to"])
      @liquidation_order.details["billing_to_id"] = record.id
      @liquidation_order.details["billing_to_name"] = record.vendor_name
    end
    
    ActiveRecord::Base.transaction do
      if @liquidation_order.save
        # beam API starts
        url =  Rails.application.credentials.beam_url+"/api/lots/assign_winner"
        serializable_resource = {lot_name: @liquidation_order.lot_name, winner_price: @liquidation_order.winner_amount,
            winner_user: @liquidation_order.winner_code, lot_status: @liquidation_order.status, remarks: @liquidation_order.remarks, amount_received: @liquidation_order.amount_received}.as_json
        # response = RestClient.post(url, serializable_resource, :verify_ssl => OpenSSL::SSL::VERIFY_NONE)
        response = RestClient::Request.execute(method: :post, url: url, payload: serializable_resource, verify_ssl: OpenSSL::SSL::VERIFY_NONE)
        # beam API ends
        if params[:winner_dispatch_status] == "true"
          @liquidation_item_list = @liquidation_order.liquidations  
          warehouse_order = @liquidation_order.warehouse_orders.create( 
            orderable:  @liquidation_order, 
            vendor_code: params[:winner_user], 
            total_quantity:  @liquidation_item_list.count, 
            client_id: @liquidation_item_list.last.client_id,
            reference_number: @liquidation_order.order_number,
            distribution_center_id: @liquidation_item_list.first.distribution_center_id, 
            status_id:LookupValue.find_by(code:Rails.application.credentials.order_status_warehouse_pending_pick).id)    

          @liquidation_item_list.each do |liquidation_item|
            original_code, status_id = LookupStatusService.new("Dispatch", "pending_pick_and_pack").call
            liquidation_item.update(status: original_code, status_id: status_id)
            details = { "#{liquidation_item.status.try(:downcase).try(:strip).split(' ').join('_')}_created_at" => Time.now,
              "status_changed_by_user_id" => current_user.id,
              "status_changed_by_user_name" => current_user.full_name,
            }
            liquidation_item.liquidation_histories.create(status_id: liquidation_item.status_id, details: details)

           client_sku_master = ClientSkuMaster.find_by_code(liquidation_item.sku_code)  rescue nil
           client_category = client_sku_master.client_category rescue nil

            WarehouseOrderItem.create( warehouse_order_id:warehouse_order.id , 
              inventory_id: liquidation_item.inventory_id , 
              client_category_id: client_category.try(:id) , 
              client_category_name: client_category.try(:name) , 
              sku_master_code: client_sku_master.try(:code) , 
              item_description: liquidation_item.item_description , 
              tag_number: liquidation_item.tag_number , 
              serial_number: liquidation_item.inventory.serial_number , 
              quantity: liquidation_item.sales_price , 
              status_id:LookupValue.find_by(code:Rails.application.credentials.order_status_warehouse_pending_pick).id, 
              status: LookupValue.find_by(code:Rails.application.credentials.order_status_warehouse_pending_pick).original_code)
          end
        end
        render json: @liquidation_order
      else
        render json: @liquidation_order.errors, status: :unprocessable_entity
      end
    end # transaction end
  end


  def moving_lot_creation
    regrade_status = LookupValue.find_by(code:Rails.application.credentials.liquidation_regrade_pending_status)
    request_status = LookupValue.find_by(code: 'request_status_fully_graded')
    liquidation_request = LiquidationRequest.new(total_items: params[:selected_inventories].size, graded_items: params[:selected_inventories].count, status: request_status.original_code, status_id: request_status.id)
    liquidation_request.request_id = liquidation_request.request_number
    if liquidation_request.save
      liquidation_ids = []
      liquidation_histories = []
      liquidation_items = Liquidation.where("id in (?)", params[:selected_inventories])
      original_code, status_id = LookupStatusService.new('Liquidation', 'moving_lot_creation').call
      liquidation_items.update_all(status: original_code, status_id: status_id, liquidation_request_id: liquidation_request.id)
      liquidation_items.each do |liquidation_item|
        liquidation_histories << {  liquidation_id: liquidation_item.id , 
                                    status_id: status_id, 
                                    status: original_code,
                                    details: {"status_changed_by_user_id" => current_user.id, "status_changed_by_user_name" => current_user.full_name },
                                    created_at: Time.now, updated_at: Time.now }
      end
      LiquidationHistory.upsert_all(liquidation_histories.flatten)      
      render json: "success"
    else
      render json: liquidation_request.errors, status: :unprocessable_entity
    end
  end


  def regrade_inventories
    set_pagination_params(params)
    status = LookupValue.find_by(code:Rails.application.credentials.liquidation_regrade_pending_status)
    request_status = LookupValue.find_by(code: 'request_status_pending')
    liquidation_request = LiquidationRequest.new(total_items: params[:selected_inventories].size, graded_items: 0, status: request_status.original_code, status_id: request_status.id)
    liquidation_request.request_id = liquidation_request.request_number
    if liquidation_request.save
      liquidation_ids = []
      liquidation_histories = []
      params[:selected_inventories].collect {|param| liquidation_ids << param["id"]}
      liquidation_items = Liquidation.where("id in (?)", liquidation_ids)   
      liquidation_items.update_all(status: status.original_code, status_id: status.id, liquidation_request_id: liquidation_request.id)
      liquidation_items.each do |liquidation_item|
        liquidation_histories << {  liquidation_id: liquidation_item.id , 
                                    status_id: status.try(:id), 
                                    status: status.try(:original_code),
                                    details: {"status_changed_by_user_id" => current_user.id, "status_changed_by_user_name" => current_user.full_name },
                                    created_at: Time.now, updated_at: Time.now}
      end
      LiquidationHistory.upsert_all(liquidation_histories.flatten)
      render json: "success"
    else
      render json: liquidation_request.errors, status: :unprocessable_entity
    end
  end

  def fetch_pending_regrading_inventories
    @inventories = Liquidation.where(status:LookupValue.find_by(code:Rails.application.credentials.liquidation_regrade_pending_status).original_code, is_active: true)
    render json: @inventories
  end

# /api/v1/warehouse/liquidations/update_liquidation
  def update_liquidation_cell  
    column_name =  params[:column_name]  
    column_value =  params[:column_value]
    data_id =  params[:id]    
    @liquidation_obj = Liquidation.find(data_id)
    @liquidation_obj.send "#{column_name}=".to_sym, column_value 
    if @liquidation_obj.save 
       render json: @liquidation_obj
    else
       render json: @liquidation_obj.errors, status: :unprocessable_entity
    end    
  end

  def get_quotations
    @quotations = Quotation.where(liquidation_order_id: params[:lot_id])
    render json: @quotations
  end

  def get_email_vendors_list
    @email_vendors = LiquidationOrderVendor.includes(:vendor_master).where(liquidation_order_id: params[:lot_id])
    render json: @email_vendors
  end

  def get_dispositions
    lookup_key = LookupKey.find_by_code('WAREHOUSE_DISPOSITION')
    dispositions = lookup_key.lookup_values.where.not(original_code: ['Liquidation', 'Pending Transfer Out', 'RTV']).order('original_code asc')
    render json: {dispositions: dispositions.as_json(only: [:id, :original_code])}
  end

  def set_disposition
    disposition = LookupValue.find_by_id(params[:disposition])
    @liquidations = Liquidation.includes(:inventory).where(id: params[:liquidation_ids])
    if @liquidations.present? && disposition.present?
      @liquidations.each do |liquidation|
        begin
          ActiveRecord::Base.transaction do
            begin
              liquidation.assigned_disposition = disposition.original_code
              liquidation.assigned_id = current_user.id
              liquidation.save!            
            rescue => exc
              raise CustomErrors.new exc
            end

            inventory = liquidation.inventory
            #& It will create approval request for current liquidation record
            details = { 
              tag_number: liquidation.tag_number,
              article_number: liquidation.sku_code,
              brand: inventory.details['brand'],
              mrp: inventory.item_price,
              description: inventory.item_description,
              requested_by: current_user.full_name,
              grade: liquidation.grade,
              inventory_created_date: CommonUtils.format_date(inventory.created_at.to_date),
              requested_date: CommonUtils.format_date(Date.current.to_date),
              requested_disposition: disposition.original_code,
              distribution_center: liquidation.distribution_center&.name,
              subject: "Approval required for Disposition of #{liquidation.sku_code} in RPA:#{liquidation.distribution_center&.name}",
              rims_url: get_host,
              rule_engine_type: get_rule_engine_type
            }
            ApprovalRequest.create_approval_request(object: liquidation, request_type: 'liquidation', request_amount: liquidation.item_price, details: details)
          end
        rescue ActiveRecord::RecordInvalid => exception
          render json: {error: "Already sent for a Disposition Approval"}, status: :unprocessable_entity
          return
        end
      end

      render json: {message: "Admin successfully notified for Disposition Approval"}, status: 200
    else
      render json: {error: "Please provide Valid Ids"}, status: :unprocessable_entity
    end
    
  end

  # def set_disposition
  #   disposition = LookupValue.find_by_id(params[:disposition])
  #   @liquidations = Liquidation.includes(:inventory).where(id: params[:liquidation_ids])
  #   if @liquidations.present? && disposition.present?
  #     @liquidations.each do |liquidation|
  #       begin
  #         ActiveRecord::Base.transaction do
  #           inventory = liquidation.inventory
  #           liquidation.details['disposition_set'] = true
  #           liquidation.is_active = false
  #           inventory.disposition = disposition.original_code
  #           liquidation.details['disposition_remark'] = params['desposition_remarks']
  #           inventory.disposition = disposition.original_code
  #           inventory.save
  #           liquidation.save

  #           if params[:files].present?
  #             params[:files].each do |file|
  #               liquidation.liquidation_attachments.create(attachment_file: file, attachment_file_type: "Disposition" , attachment_file_type_id: 806)
  #             end
  #           end
  #           DispositionRule.create_bucket_record(disposition.original_code, inventory, 'Liquidation', current_user.id)
  #         end
  #       rescue ActiveRecord::RecordInvalid => exception
  #         render json: "Something Went Wrong", status: :unprocessable_entity
  #         return
  #       end
  #     end

  #     render json: "success", status: 200
  #   else
  #     render json: "Please provide Valid Ids", status: :unprocessable_entity
  #   end
  # end

  def get_liquidation_requests
    @liquidation_requests = LiquidationRequest.includes(:liquidations)
    render json: @liquidation_requests
  end

  def move_to_pending_liquidation
    liquidation_pending_status = LookupValue.where(code:Rails.application.credentials.liquidation_pending_status).first
    @liquidations = Liquidation.where(id: params[:liquidation_ids])
    if @liquidations.present?
      @liquidations.each do |liquidation|
        begin
          ActiveRecord::Base.transaction do
            liquidation.status = liquidation_pending_status.original_code
            liquidation.status_id = liquidation_pending_status.id
            liquidation_request = liquidation.liquidation_request
            liquidation.liquidation_request_id = nil
            if liquidation_request.present?
              if liquidation_request.total_items == liquidation_request.graded_items
                status = LookupValue.find_by_code('request_status_fully_graded')
                liquidation_request.update(total_items: liquidation_request.total_items - 1, graded_items: liquidation_request.graded_items - 1, status: status.original_code, status_id: status.id)
              else
                liquidation_request.update(total_items: liquidation_request.total_items - 1)
                if liquidation_request.total_items == liquidation_request.graded_items
                  status = LookupValue.find_by_code('request_status_fully_graded')
                  liquidation_request.update(status: status.original_code, status_id: status.id)
                end
              end
              liquidation_request.delete if liquidation_request.total_items ==0
            end
            liquidation.details['moved_from_lot_creation'] = true
            if liquidation.save
              new_liquidation_status = LookupValue.where(code: Rails.application.credentials.liquidation_pending_status).first
              LiquidationHistory.create(
                liquidation_id: liquidation.id , 
                status_id: new_liquidation_status.try(:id), 
                status: new_liquidation_status.try(:original_code),
                details: {"status_changed_by_user_id" => current_user.id, "status_changed_by_user_name" => current_user.full_name } )
            end
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
        @distribution_center_detail = distribution_center_user.details.select{|d| d["disposition"] == "Liquidation" || d["disposition"] == "All"}.last
        if @distribution_center_detail.present?
          @distribution_center_ids = @distribution_center_detail["warehouse"].include?(0) ? DistributionCenter.all.pluck(:id) : @distribution_center_detail["warehouse"]
          return
        end
      end
    else
      @distribution_center_ids = @distribution_center.present? ? [@distribution_center.id] : DistributionCenter.all.pluck(:id)
    end
  end

  def get_item_type(item)
    item = ClientSkuMaster.find_by_code(item.sku_code)
    return item.own_label
  end

  def republish_params
    params.permit(:lot_name, :lot_mrp, :lot_desc, :buy_now_price, :floor_price, :reserve_price, :increment_slab, :start_date, :end_date, :id, :images, :new_bid_master_id, :message, :status, :lot_attachment_ids, :error_message)
  end

  def clean_and_abort_the_republish_if_service_responded_with_error
    return if republish_params[:status] == "200"
    render_error republish_params[:error_message]
  end

  def render_error message
    delete_unused_lot_attachments
    @old_liquidation_order.update(republish_status: 'error')
    render json: { errors: message }, status: 500 and return
  end

  def delete_unused_lot_attachments
    @lot_attachments.destroy_all if @lot_attachments.present?
  end

  def lot_attachments
    @lot_attachments = LotAttachment.where(id: params[:lot_attachment_ids])
  end

  def check_for_republish_errors
    errors_hash = []
    errors_hash << "Lot Name can not be blank" if params[:lot_name].blank?
    errors_hash << "Floor Price can not be blank" if params[:floor_price].blank?
    errors_hash << "Reserve Price can not be blank" if params[:reserve_price].blank?
    errors_hash << "Buy Now Price can not be blank" if params[:buy_now_price].blank?
    errors_hash << "Increment Slab can not be blank" if params[:increment_slab].blank?
    errors_hash << "Start Date can not be blank" if params[:start_date].blank?
    errors_hash << "End Date can not be blank" if params[:end_date].blank?
    render json: { errors: errors_hash }, status: 500 and return if errors_hash.present?
  end

  def set_liquidation_order
    @old_liquidation_order = LiquidationOrder.find_by(id: params[:id])
    render json: { errors: ["Liquidation order with given Id #{params[:id]} is not Found!"] }, status: 500 and return if @old_liquidation_order.blank?
  end

  def lot_attachment_ids
    attachment_ids =  []
    if params[:files].present?
      params[:files].each do |file|
        attachment = LotAttachment.new(attachment_file: file)
        attachment.save(validate: false)
        attachment_ids << attachment.id
      end
    end
    attachment_ids
  end

  def check_if_republish_already_in_progress
    render json: { errors: ["Liquidation order with given Id #{params[:id]} is already queued for republish."] }, status: 422 and return if @old_liquidation_order.republish_pending?
  end
end
