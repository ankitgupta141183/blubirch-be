class Api::V1::Warehouse::ReturnToVendorController < ApplicationController

  # GET api/v1/warehouse/return_to_vendor
  def index
    get_inventories
    if current_user.roles.last.name == "Default User"
      @items = check_user_accessibility(@vendor_returns, @distribution_center_detail)
      @vendor_returns = @vendor_returns.where(id: @items.pluck(:id))
    end
    @vendor_returns = @vendor_returns.page(@current_page).per(@per_page)
    render json: @vendor_returns, meta: pagination_meta(@vendor_returns)
  end

  def search_item
    set_pagination_params(params)
    get_inventories
    if current_user.roles.last.name == "Default User"
      @items = check_user_accessibility(@vendor_returns, @distribution_center_detail)
      @vendor_returns = @vendor_returns.where(id: @items.pluck(:id))
    end
    search_param = params['search'].split(',').collect(&:strip).flatten
    if params['search_in'] == 'brand'
      @vendor_returns = @vendor_returns.where("lower(vendor_returns.details ->> 'brand') IN (?) ", search_param.map(&:downcase))
    elsif (params['search_in'] == 'lot_id' && search_param.present?)
      @vendor_returns = @vendor_returns.where(vendor_return_order_id: search_param)
    else
      @vendor_returns = @vendor_returns.where("lower(vendor_returns.#{params['search_in']}) IN (?) ", search_param.map(&:downcase))
    end
    @vendor_returns = @vendor_returns.page(@current_page).per(@per_page)
    render json: @vendor_returns, meta: pagination_meta(@vendor_returns)
  end

  # POST api/v1/warehouse/return_to_vendor/send_for_claim
  def send_for_claim
    inventories = Inventory.includes(:vendor_return, :client, :distribution_center).where(id: params[:inventory_ids])

    if inventories.present?
      file_type = LookupValue.find_by_code(Rails.application.credentials.rtv_file_type_claim)
      inventories.each do |inventory|
        begin
          ActiveRecord::Base.transaction do
            record = inventory.vendor_return
            step = if record.work_flow_name == 'Flow 2'
              'pending_brand_approval'
            else
              'pending_call_log'
            end
            original_code, status_id = LookupStatusService.new("Brand Call-Log", step).call
            record.claim_email_date           = params[:email_date].to_datetime
            record.claim_rgp_number           = params[:claim_rgp_number] if params[:claim_rgp_number].present?
            record.claim_replacement_location = params[:claim_replacement_location]
            record.blubirch_claim_id          = "BB-CL-#{SecureRandom.hex(3)}"
            record.status_id                  = status_id
            record.status                     = original_code
            inventory.details['rtv_status'] = original_code
            if record.save!
              inventory.save
              if params[:files].present?
                params[:files].each do |file|
                  attach = record.rtv_attachments.new(attachment_file: file, attachment_file_type: file_type.original_code, attachment_file_type_id: file_type.id)

                  attach.save!
                end
              end
              details = { "#{record.status.try(:downcase).try(:strip).split(' ').join('_')}_created_at" => Time.now,
                "status_changed_by_user_id" => current_user.id,
                "status_changed_by_user_name" => current_user.full_name,
              }

              vendor_return_history = record.vendor_return_histories.new(status_id: record.status_id, details: details)
              vendor_return_history.save!
            end
          end
        rescue ActiveRecord::RecordInvalid => exception
          render json: "Something Went Wrong", status: :unprocessable_entity
          return
        end
      end
      get_inventories
      @vendor_returns = @vendor_returns.page(@current_page).per(@per_page)
      render json: @vendor_returns
    else
      render json: "Please provide Valid Inventory Ids", status: :unprocessable_entity
    end
  end

  def get_dispositions
    lookup_key = LookupKey.find_by_code('WAREHOUSE_DISPOSITION')
    dispositions = lookup_key.lookup_values.where.not(original_code: ['Pending Disposition', 'Brand Call-Log', 'Pending Transfer Out', 'RTV']).order('original_code asc')
    policy_key = LookupKey.find_by_code('POLICY')
    policies = policy_key.lookup_values
    render json: {dispositions: dispositions.as_json(only: [:id, :original_code]), policies: policies.as_json(only: [:id, :original_code])}
  end

  def update_call_log
    inventories = Inventory.includes(:vendor_return, :client, :distribution_center).where(id: params[:inventory_ids])

    if inventories.present?
      inventories.each do |inventory|
        begin
          ActiveRecord::Base.transaction do
            record = inventory.vendor_return

            step = if ['Flow 2', 'Flow 3'].include?(record.work_flow_name)
              'pending_brand_approval'
            else
              'pending_brand_inspection'
            end

            original_code, status_id = LookupStatusService.new("Brand Call-Log", step).call

            record.call_log_id = params[:call_log_id].gsub(/[^0-9A-Za-z\\-]/, '')
            record.status_id   = status_id
            record.status      = original_code
            inventory.details['rtv_status'] = original_code
            if record.save!
              inventory.save
              details = { "#{record.status.try(:downcase).try(:strip).split(' ').join('_')}_created_at" => Time.now,
                "status_changed_by_user_id" => current_user.id,
                "status_changed_by_user_name" => current_user.full_name,
              }
              vendor_return_history = record.vendor_return_histories.new(status_id: record.status_id, details: details)
              vendor_return_history.save!
            end
          end
        rescue ActiveRecord::RecordInvalid => exception
          render json: "Something Went Wrong", status: :unprocessable_entity
          return
        end
      end
      get_inventories
      @vendor_returns = @vendor_returns.page(@current_page).per(@per_page)
      render json: @vendor_returns
    else
      render json: "Please provide Valid Inventory Ids", status: :unprocessable_entity
    end
  end

  def update_inspection_details
    inventories = Inventory.includes(:vendor_return, :client, :distribution_center).where(id: params[:inventory_ids])
    if inventories.present?
      original_code, status_id = LookupStatusService.new("Brand Call-Log", 'pending_brand_approval').call
      file_type = LookupValue.find_by_code(Rails.application.credentials.rtv_file_type_inspection)
      inventories.each do |inventory|
        begin
          ActiveRecord::Base.transaction do
            record = inventory.vendor_return
            record.brand_inspection_date           = params['inspection_date'].to_datetime
            record.brand_inspection_remarks        = params['inspection_remark']
            record.inspection_rgp_number           = params[:inspection_rgp_number] if params[:inspection_rgp_number].present?
            record.inspection_replacement_location = params[:inspection_replacement_location]
            record.status_id                       = status_id
            record.status                          = original_code
            inventory.details['rtv_status'] = original_code
            if record.save!
              inventory.save
              if params[:files].present?
                params[:files].each do |file|
                  attach = record.rtv_attachments.new(attachment_file: file, attachment_file_type: file_type.original_code, attachment_file_type_id: file_type.id)
                  attach.save!
                end
              end
              details = { "pending_brand_approval_created_at" => Time.now,
                "status_changed_by_user_id" => current_user.id,
                "status_changed_by_user_name" => current_user.full_name,
              }
              vendor_return_history = record.vendor_return_histories.new(status_id: record.status_id, details: details)
              vendor_return_history.save!
            end
          end
        rescue ActiveRecord::RecordInvalid => exception
          render json: "Something Went Wrong", status: :unprocessable_entity
          return
        end
      end
      get_inventories
      @vendor_returns = @vendor_returns.page(@current_page).per(@per_page)
      render json: @vendor_returns
    else
      render json: "Please provide Valid Inventory Ids", status: :unprocessable_entity
    end
  end

  # POST api/v1/warehouse/return_to_vendor/approve_reject_inventory
  def approve_reject_inventory
    if params['claim_action'] == 'Approve'
      vendor_return_status = LookupValue.find_by_code(Rails.application.credentials.vendor_return_status_pending_dispatch)
    elsif params['claim_action'] == 'Reject'
      vendor_return_status = LookupValue.find_by_code(Rails.application.credentials.vendor_return_status_pending_disposition)
    end
    inventory = Inventory.find_by_id(params[:inventory_id])
    #Check if inventory is already in Approved/Rejected
    if inventory.present?
      begin
        ActiveRecord::Base.transaction do
          record = inventory.vendor_return
          if params['files'].present?
            params['files'].each do |file|
              attach = record.rtv_attachments.new(attachment_file: file, attachment_file_type: file_type.original_code, attachment_file_type_id: file_type.id) unless file.blank?
              attach.save!
            end
          end
          record.status_id = vendor_return_status.id
          record.status = vendor_return_status.original_code
          record.action_remark = params['action_remark']
          record.resolution_date = Time.now

          inventory.details['rtv_status'] = vendor_return_status.original_code
          inventory.details['pick'] = true if vendor_return_status.code == 'vendor_return_status_pending_dispatch'
          inventory.save
          if record.save!
            vrh = record.vendor_return_histories.new(status_id: record.status_id)
            vrh.details = {}
            vrh.details['pending_dispatch_created_at'] = Time.now if vendor_return_status.code == 'vendor_return_status_pending_dispatch'
            vrh.details['pending_disposition_created_at'] = Time.now if vendor_return_status.code == 'vendor_return_status_pending_disposition'
            vrh.details["status_changed_by_user_id"] = current_user.id
            vrh.details["status_changed_by_user_name"] = current_user.full_name
            vrh.save!
          end
        end
      rescue ActiveRecord::RecordInvalid => exception
        render json: "Something Went Wrong", status: :unprocessable_entity
        return
      end

      get_inventories
      @vendor_returns = @vendor_returns.page(@current_page).per(@per_page)
      render json: @vendor_returns
    else
      render json: "Please provide Valid Inventory Ids / Claim id", status: :unprocessable_entity
    end
  end

  # PUT api/v1/warehouse/return_to_vendor/set_disposition
  def set_disposition
    disposition = LookupValue.find_by_id(params[:disposition])
    @inventories = Inventory.includes(:vendor_return, :client, :distribution_center).where(id: params[:inventory_ids])
    file_type = LookupValue.find_by_code(Rails.application.credentials.rtv_file_type_disposition)
    policy = LookupValue.find_by_id(params['policy']) if params['policy'].present?
    warehouse_disposition_liquidation = LookupValue.where(code: Rails.application.credentials.warehouse_disposition_liquidation).first.try(:original_code)
    if @inventories.present? && disposition.present?
      #Check for RTV Disposition
      @inventories.each do |inventory|

        begin
          ActiveRecord::Base.transaction do
            record = inventory.vendor_return            
            if disposition.original_code == LookupValue.where(code: Rails.application.credentials.warehouse_disposition_rtv).first.try(:original_code)
              vendor_return_status = LookupValue.find_by_code(Rails.application.credentials.vendor_return_status_pending_dispatch)
              record.status_id = vendor_return_status.id
              record.status = vendor_return_status.original_code
              record.resolution_date = Time.now
              record.disposition_remark = params['remark']
              inventory.disposition = disposition.original_code
              inventory.details['rtv_status'] = vendor_return_status.original_code
              inventory.save
              if record.save!
                vrh = record.vendor_return_histories.new(status_id: record.status_id)
                vrh.details = {}
                vrh.details['pending_dispatch_created_at'] = Time.now
                vrh.details["status_changed_by_user_id"] = current_user.id
                vrh.details["status_changed_by_user_name"] = current_user.full_name
                vrh.save!
              end
            elsif disposition.original_code == LookupValue.where(code: Rails.application.credentials.warehouse_disposition_replacement).first.try(:original_code) || disposition.original_code == LookupValue.where(code: Rails.application.credentials.warehouse_disposition_repair).first.try(:original_code)
              vendor_return_status_rtv_closed = LookupValue.find_by_code(Rails.application.credentials.vendor_return_status_rtv_closed)
              record.disposition_remark = params['remark']
              inventory.disposition = disposition.original_code
              record.status_id = vendor_return_status_rtv_closed.id
              record.status = vendor_return_status_rtv_closed.original_code
              record.details['disposition_set'] = true
              record.is_active = false
              if record.save!
                # vrh = record.vendor_return_histories.new(status_id: record.status_id)
                # vrh.details = {}
                # vrh.details['rtv_closed_created_at'] = Time.now
                # vrh.details["status_changed_by_user_id"] = current_user.id
                # vrh.details["status_changed_by_user_name"] = current_user.full_name
                # vrh.save!
                inventory.save
              end
              Replacement.set_manual_disposition(record, current_user.id) if disposition.original_code == LookupValue.where(code: Rails.application.credentials.warehouse_disposition_replacement).first.try(:original_code)
              Repair.set_manual_disposition(record, current_user.id) if disposition.original_code == LookupValue.where(code: Rails.application.credentials.warehouse_disposition_repair).first.try(:original_code)

              # Create Inventory Status
              code = 'inventory_status_warehouse_pending_'+ inventory.disposition.downcase
              bucket_status =  LookupValue.where("code = ?", Rails.application.credentials.send(code)).first
              inventory.status = bucket_status.original_code
              inventory.status_id = bucket_status.id
              if inventory.save
                existing_inventory_status = inventory.inventory_statuses.where(is_active: true).last
                inventory_status = existing_inventory_status.present? ? existing_inventory_status.dup : inventory.inventory_statuses.new
                inventory_status.status = bucket_status
                inventory_status.distribution_center_id = inventory.distribution_center_id
                inventory_status.is_active = true
                existing_inventory_status.update_attributes(is_active: false) if existing_inventory_status.present?
                inventory_status.save!
              end
            else
              vendor_return_status_rtv_closed = LookupValue.find_by_code(Rails.application.credentials.vendor_return_status_rtv_closed)
              record.disposition_remark = params['remark']
              inventory.disposition = disposition.original_code
              if disposition.original_code == warehouse_disposition_liquidation
                record.details['policy_id'] = policy.id
                record.details['policy_type'] = policy.original_code
                record.details['credit_note_amount'] = params['credit_note_amount']
                inventory.details['policy_id'] = policy.id
                inventory.details['credit_note_amount'] = params['credit_note_amount']
                inventory.details['policy_type'] = policy.original_code
              end
              record.details['disposition_set'] = true
              record.is_active = false
              inventory.disposition = disposition.original_code
              record.status_id = vendor_return_status_rtv_closed.id
              record.status = vendor_return_status_rtv_closed.original_code
              if record.save!
                # vrh = record.vendor_return_histories.new(status_id: record.status_id)
                # vrh.details = {}
                # vrh.details['rtv_closed_created_at'] = Time.now
                # vrh.details["status_changed_by_user_id"] = current_user.id
                # vrh.details["status_changed_by_user_name"] = current_user.full_name
                # vrh.save!
                inventory.save
              end
              DispositionRule.create_bucket_record(disposition.original_code, inventory, 'Brand Call-Log', current_user.id)
            end
            if params['files'].present?
              params['files'].each do |file|
                attach = record.rtv_attachments.new(attachment_file: file, attachment_file_type: file_type.original_code, attachment_file_type_id: file_type.id)
                attach.save!
              end
            end
          end
        rescue ActiveRecord::RecordInvalid => exception
          render json: "Something Went Wrong", status: :unprocessable_entity
          return
        end
      end
      get_inventories
      @vendor_returns = @vendor_returns.page(@current_page).per(@per_page)
      render json: @vendor_returns
    else
      render json: "Please provide Valid Inventory Ids", status: :unprocessable_entity
    end
  end  

  # PUT api/v1/warehouse/return_to_vendor/set_disposition_on_claim
  def set_disposition_on_claim
    disposition = LookupValue.find_by_id(params[:disposition])
    @inventories = Inventory.includes(:vendor_return, :client, :distribution_center).where(id: params[:inventory_ids])
    file_type = LookupValue.find_by_code(Rails.application.credentials.rtv_file_type_disposition)
    policy = LookupValue.find_by_id(params['policy']) if params['policy'].present?    
    vendor_return_status_rtv_closed = LookupValue.find_by_code(Rails.application.credentials.vendor_return_status_rtv_closed)
    warehouse_disposition_liquidation = LookupValue.where(code: Rails.application.credentials.warehouse_disposition_liquidation).first.try(:original_code)
    if @inventories.present? && disposition.present?
      #Check for RTV Disposition
      @inventories.each do |inventory|

        begin
          ActiveRecord::Base.transaction do
            record = inventory.vendor_return
            record.disposition_remark = params['remark']
            if disposition.original_code == warehouse_disposition_liquidation
              record.details['policy_id'] = policy.id
              record.details['policy_type'] = policy.original_code
              record.details['credit_note_amount'] = params['credit_note_amount']
              inventory.details['policy_id'] = policy.id
              inventory.details['credit_note_amount'] = params['credit_note_amount']
              inventory.details['policy_type'] = policy.original_code
            end
            record.details['disposition_set'] = true
            record.is_active = false
            inventory.disposition = disposition.original_code
            record.status_id = vendor_return_status_rtv_closed.id
            record.status = vendor_return_status_rtv_closed.original_code
            if record.save!
              # vrh = record.vendor_return_histories.new(status_id: record.status_id)
              # vrh.details = {}
              # vrh.details['rtv_closed_created_at'] = Time.now
              # vrh.details["status_changed_by_user_id"] = current_user.id
              # vrh.details["status_changed_by_user_name"] = current_user.full_name
              # vrh.save!
              inventory.save
            end
            DispositionRule.create_bucket_record(disposition.original_code, inventory, "Brand Call-Log", current_user.id)
            if params['files'].present?
              params['files'].each do |file|
                attach = record.rtv_attachments.new(attachment_file: file, attachment_file_type: file_type.original_code, attachment_file_type_id: file_type.id)
                attach.save!
              end
            end
          end
        rescue ActiveRecord::RecordInvalid => exception
          render json: "Something Went Wrong", status: :unprocessable_entity
          return
        end
      end
      get_inventories
      @vendor_returns = @vendor_returns.page(@current_page).per(@per_page)
      render json: @vendor_returns
    else
      render json: "Please provide Valid Inventory Ids", status: :unprocessable_entity
    end
  end


  # POST api/v1/warehouse/return_to_vendor/create_dispatch_items
  def create_dispatch_items
    vendor_returns = VendorReturn.includes(:rtv_attachments, :inventory, :vendor_return_histories, vendor_return_order: :warehouse_orders).where(id: params[:vendor_return_ids])
    if vendor_returns.present? && vendor_returns.last.vendor_return_order.blank?
      begin
        ActiveRecord::Base.transaction do
          vendor_master = VendorMaster.find_by_vendor_code(params[:vendor_code])
          @vendor_return_order = VendorReturnOrder.new(vendor_code: vendor_master.vendor_code, lot_name: params[:lot_name].to_s.strip)
          @vendor_return_order.order_number = "OR-Brand-Call-Log-#{SecureRandom.hex(6)}"
          if @vendor_return_order.save!
            original_code, status_id = LookupStatusService.new("Dispatch", "pending_pick_and_pack").call
            #Update Vendor Return
            vendor_returns.update_all(vendor_return_order_id: @vendor_return_order.id, order_number: @vendor_return_order.order_number, status_id: status_id, status: original_code)
            # Create Warehouse order
            warehouse_order_status = LookupValue.find_by_code(Rails.application.credentials.order_status_warehouse_pending_pick)
            warehouse_order = @vendor_return_order.warehouse_orders.new(distribution_center_id: vendor_returns.first.distribution_center_id, vendor_code: @vendor_return_order.vendor_code, reference_number: @vendor_return_order.order_number)
            warehouse_order.client_id = vendor_returns.last.inventory.client_id
            warehouse_order.status_id = warehouse_order_status.id
            warehouse_order.total_quantity = @vendor_return_order.vendor_returns.count
            warehouse_order.save!

            #Create Ware house Order Items
            @vendor_return_order.vendor_returns.each do |vr|
              client_category = ClientSkuMaster.find_by_code(vr.sku_code).client_category rescue nil
              warehouse_order_item = warehouse_order.warehouse_order_items.new
              warehouse_order_item.inventory_id = vr.inventory_id
              warehouse_order_item.aisle_location = vr.aisle_location
              warehouse_order_item.toat_number = vr.toat_number
              warehouse_order_item.client_category_id = client_category.id rescue nil
              warehouse_order_item.client_category_name = client_category.name rescue nil
              warehouse_order_item.sku_master_code = vr.sku_code
              warehouse_order_item.item_description = vr.item_description
              warehouse_order_item.tag_number = vr.tag_number
              warehouse_order_item.quantity = 1
              warehouse_order_item.status_id = warehouse_order_status.id
              warehouse_order_item.status = warehouse_order_status.original_code
              warehouse_order_item.details = vr.inventory.details
              warehouse_order_item.serial_number = vr.inventory.serial_number
              warehouse_order_item.save!
              details = { "#{original_code.try(:downcase).try(:strip).split(' ').join('_')}_created_at" => Time.now,
                "status_changed_by_user_id" => current_user.id,
                "status_changed_by_user_name" => current_user.full_name,
              }
              vr.vendor_return_histories.create(status_id: status_id, details: details)
            end
          end
        end
      rescue ActiveRecord::RecordInvalid => exception
        render json: "Something Went Wrong", status: :unprocessable_entity
        return
      end
      render json: {order_number: @vendor_return_order.order_number}
    else
      render json: "Please provide Valid VendorReturn Id", status: :unprocessable_entity
    end
  end

  # POST api/v1/warehouse/return_to_vendor/claim_settlement
  def claim_settlement
    vr_status = LookupValue.find_by_code(Rails.application.credentials.vendor_return_status_rtv_closed)
    inventory_status_closed = LookupValue.where("code = ?", Rails.application.credentials.inventory_status_warehouse_closed_successfully).first
    inventory = Inventory.find_by_id(params[:inventory_id])
    file_type = LookupValue.find_by_code(Rails.application.credentials.rtv_file_type_settlement)
    vendor_return = inventory.vendor_return
    if params['approved_amount'].present? && params['settlement_date'].present?
      begin
        ActiveRecord::Base.transaction do
          if vendor_return.update_attributes!(settlement_amount: params['approved_amount'].to_f, settlement_date: params[:settlement_date].to_date, settlement_remark: params['settlement_remark'], status_id: vr_status.id, status: vr_status.original_code, is_active: false)
            inventory_status_active = inventory.inventory_statuses.where(is_active: true).try(:last)
            inventory.inventory_statuses.build(status_id: inventory_status_closed.id, user_id: current_user.id, distribution_center_id: inventory.distribution_center_id, details: {"user_id" => current_user.id, "user_name" => current_user.username})
            inventory.status_id = inventory_status_closed.id
            inventory.status = inventory_status_closed.original_code
            if inventory.save!
              inventory_status_active.update(is_active: false) if inventory_status_active.present?
            end
            details = { "rtv_closed_created_at" => Time.now, "status_changed_by_user_id" => current_user.id, "status_changed_by_user_name" => current_user.full_name }
            vendor_return.vendor_return_histories.create(status_id: vr_status.id, details: details)
          end
          if params['files'].present?
            params['files'].each do |file|
              attach = vendor_return.rtv_attachments.new(attachment_file: file, attachment_file_type: file_type.original_code, attachment_file_type_id: file_type.id)
              attach.save!
            end
          end
        end
      rescue ActiveRecord::RecordInvalid => exception
        render json: "Something Went Wrong", status: :unprocessable_entity
        return
      end

      get_inventories
      @vendor_returns = @vendor_returns.page(@current_page).per(@per_page)
      render json: @vendor_returns
    else
      render json: "Please provide Valid Inventory", status: :unprocessable_entity
    end
  end

  # GET /api/v1/warehouse/return_to_vendor/get_vendor_master
  def get_vendor_master
    @vendor_master = VendorMaster.joins(:vendor_types).where('vendor_types.vendor_type': ["Brand Call-Log", "Internal Vendor"]).where.not(vendor_code: current_user.distribution_centers.pluck(:code)).distinct
    render json: @vendor_master
  end

  def edit_information
    vendor_returns = VendorReturn.where(id: params[:vendor_return_ids])
    begin
      ActiveRecord::Base.transaction do
        vendor_returns.each do |vr|
          inventory = vr.inventory
          inventory.details['invoice_number'] = params[:invoice_number]
          inventory.save!
          file_type_id = LookupValue.find_by(code: "return_reason_file_types_customer_invoice").id
          invoice_document = inventory.inventory_documents.where(document_name_id: file_type_id).last || inventory.inventory_documents.new(document_name_id: file_type_id)
          invoice_document.reference_number = params[:invoice_number]
          invoice_document.save!
        end
      rescue ActiveRecord::RecordInvalid => exception
        render json: "Something Went Wrong", status: :unprocessable_entity
        return
      end
    end
    render json: 'Success', status: 200
  end

  private

  def get_inventories
    set_pagination_params(params)
    get_distribution_centers(params)
    ids = @distribution_center.present? ? [@distribution_center.id] : current_user.distribution_centers.pluck(:id)
    status = params[:status].class.to_s == 'Array' ? params[:status] : params['status'].to_s.split(",")
    @vendor_returns = VendorReturn.includes(:inventory, :rtv_attachments, :vendor_return_histories, vendor_return_order: :warehouse_orders).where(distribution_center_id: ids, is_active: true, status: status).order('vendor_returns.updated_at desc')
    # @vendor_returns = @vendor_returns.where("inventories.is_putaway_inwarded IS NOT false")
    @vendor_returns = @vendor_returns.where("lower(vendor_returns.details ->> 'criticality') IN (?) ", params[:criticality].downcase) if params['criticality'].present?
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

  def get_distribution_centers(params)
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
        if params["bucket"] == "RTV"
          @distribution_center_detail = distribution_center_user.details.select{|d| d["disposition"] == "RTV" || d["disposition"] == "All"}.last
        else
          @distribution_center_detail = distribution_center_user.details.select{|d| d["disposition"] == "Brand Call-Log" || d["disposition"] == "All"}.last
        end
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
