class Api::V1::Warehouse::InsurancesController < ApplicationController

  # GET api/v1/warehouse/insurances
  def index
    get_insurance
    if current_user.roles.last.name == "Default User"
      @items = check_user_accessibility(@insurances, @distribution_center_detail)
      @insurances = @insurances.where(id: @items.pluck(:id)).order('updated_at desc')
    end
    @insurances = @insurances.page(@current_page).per(@per_page)
    render json: @insurances, each_serializer: Api::V1::Warehouse::OldInsuranceSerializer, meta: pagination_meta(@insurances)
  end

  def search_item
    get_distribution_centers
    set_pagination_params(params)
    search_param = params['search'].split(',').collect(&:strip).flatten
    @insurances = Insurance.joins(:inventory).where(status: params['status'], is_active: true, distribution_center_id: @distribution_center_ids).where("lower(insurances.#{params['search_in']}) IN (?) ", search_param.map(&:downcase))
    @insurances = @insurances.where("inventories.is_putaway_inwarded IS NOT false")
    @insurances - @insurances.where("lower(insurances.details ->> 'criticality') IN (?) ", params[:criticality]) if params['criticality'].present?
    @insurances = @insurances.page(@current_page).per(@per_page)
    render json: @insurances, each_serializer: Api::V1::Warehouse::OldInsuranceSerializer, meta: pagination_meta(@insurances)
  end

  def submit_for_insurance
    insurances = Insurance.where(id: params[:insurance_ids])
    if insurances.present?
      ins_status = LookupValue.find_by_code(Rails.application.credentials.insurance_status_pending_insurance_call_log)
      file_type = LookupValue.find_by_code(Rails.application.credentials.insurance_file_type_insurance_submission)
      begin
        ActiveRecord::Base.transaction do
          insurances.each do |insurance|
            insurance.status_id = ins_status.id
            insurance.status = ins_status.original_code
            insurance.claim_amount = params['claim_amount'].to_f
            insurance.claim_submission_date = params['claim_submission_date'].to_datetime
            insurance.claim_submission_remarks = params['claim_remark']
            insurance.inventory.details['insurance_status'] = ins_status.original_code
            insurance.inventory.save
            if insurance.save!
              if params["files"].present?
                params["files"].each do |file|
                  insurance.insurance_attachments.create!(attachment_file: file, attachment_file_type: file_type.original_code)
                end
              end
              ih = insurance.insurance_histories.new(status_id: insurance.status_id)
              ih.details = {}
              key = "#{insurance.status.try(:downcase).try(:strip).split(' ').join('_')}_created_at"
              ih.details[key] = Time.now
              ih.details["status_changed_by_user_id"] = current_user.id
              ih.details["status_changed_by_user_name"] = current_user.full_name
              ih.save!
            end
          end
        end
      rescue ActiveRecord::RecordInvalid => exception
        render json: "Something Went Wrong", status: :unprocessable_entity
        return
      end
      get_insurance
      @insurances = @insurances.page(@current_page).per(@per_page)
      render json: @insurances, each_serializer: Api::V1::Warehouse::OldInsuranceSerializer
    else
      render json: "Please provide Valid Id", status: :unprocessable_entity
    end
  end

  def update_call_log
    insurances = Insurance.where(id: params[:insurance_ids])
    ins_status = LookupValue.find_by_code(Rails.application.credentials.insurance_status_pending_insurance_inspection)
    if insurances.present?
      begin
        ActiveRecord::Base.transaction do
          insurances.each do |insurance|
            insurance.call_log_id = params[:call_log_id].gsub(/[^0-9A-Za-z\\-]/, '')
            insurance.status_id = ins_status.id
            insurance.status = ins_status.original_code
            insurance.inventory.details['insurance_status'] = ins_status.original_code
            if insurance.save!
              insurance.inventory.save
              ih = insurance.insurance_histories.new(status_id: insurance.status_id)
              ih.details = {}
              key = "#{insurance.status.try(:downcase).try(:strip).split(' ').join('_')}_created_at"
              ih.details[key] = Time.now
              ih.details["status_changed_by_user_id"] = current_user.id
              ih.details["status_changed_by_user_name"] = current_user.full_name
              ih.save!
            end
          end
        end
      rescue ActiveRecord::RecordInvalid => exception
        render json: "Something Went Wrong", status: :unprocessable_entity
        return
      end
      get_insurance
      @insurances = @insurances.page(@current_page).per(@per_page)
      render json: @insurances, each_serializer: Api::V1::Warehouse::OldInsuranceSerializer
    else
      render json: "Please provide Valid Id", status: :unprocessable_entity
    end
  end

  def submit_inspection
    insurances = Insurance.where(id: params[:insurance_ids])
    ins_status = LookupValue.find_by_code(Rails.application.credentials.insurance_status_pending_insurance_approval)
    file_type = LookupValue.find_by_code(Rails.application.credentials.insurance_file_type_insurance_inspection)
    if insurances.present?
      begin
        ActiveRecord::Base.transaction do
          insurances.each do |insurance|
            insurance.claim_inspection_date = params['claim_inspection_date'].to_datetime
            insurance.claim_inspection_remarks = params['claim_inspection_remarks']
            insurance.status_id = ins_status.id
            insurance.status = ins_status.original_code
            insurance.inventory.details['insurance_status'] = ins_status.original_code
            if insurance.save!
              insurance.inventory.save
              if params["files"].present?
                params["files"].each do |file|
                  insurance.insurance_attachments.create!(attachment_file: file, attachment_file_type: file_type.original_code)
                end
              end
              ih = insurance.insurance_histories.new(status_id: insurance.status_id)
              ih.details = {}
              key = "#{insurance.status.try(:downcase).try(:strip).split(' ').join('_')}_created_at"
              ih.details[key] = Time.now
              ih.details["status_changed_by_user_id"] = current_user.id
              ih.details["status_changed_by_user_name"] = current_user.full_name
              ih.save!
            end
          end
        end
      rescue ActiveRecord::RecordInvalid => exception
        render json: "Something Went Wrong", status: :unprocessable_entity
        return
      end
      get_insurance
      @insurances = @insurances.page(@current_page).per(@per_page)
      render json: @insurances, each_serializer: Api::V1::Warehouse::OldInsuranceSerializer
    else
      render json: "Please provide Valid Id", status: :unprocessable_entity
    end
  end

  def approve_reject_insurance
    if params['action_type'] == 'Approve'
      file_type = LookupValue.find_by_code(Rails.application.credentials.insurance_file_type_insurance_resolution)
      insurance_status = LookupValue.find_by_code(Rails.application.credentials.insurance_status_pending_insurance_dispatch)
    elsif params['action_type'] == 'Reject'
      file_type = LookupValue.find_by_code(Rails.application.credentials.insurance_file_type_insurance_disposition)
      insurance_status = LookupValue.find_by_code(Rails.application.credentials.insurance_status_pending_insurance_disposition)
    end
    insurances = Insurance.where(id: params[:insurance_ids])
    #Check if inventory is already in Approved/Rejected
    if insurances.present?
      begin
        ActiveRecord::Base.transaction do
          insurances.each do |insurance|
            insurance.status_id = insurance_status.id
            insurance.status = insurance_status.original_code
            insurance.approved_amount = params[:approved_amount].to_f if params['action_type'] == 'Approve'
            insurance.action_remarks = params[:action_remarks]
            insurance.resolution_date = Time.now
            insurance.inventory.details['insurance_status'] = insurance_status.original_code

            if insurance.save!
              insurance.inventory.save
              if params["files"].present?
                params["files"].each do |file|
                  insurance.insurance_attachments.create!(attachment_file: file, attachment_file_type: file_type.original_code)
                end
              end
              ih = insurance.insurance_histories.new(status_id: insurance.status_id)
              ih.details = {}
              key = "#{insurance.status.try(:downcase).try(:strip).split(' ').join('_')}_created_at"
              ih.details[key] = Time.now
              ih.details["status_changed_by_user_id"] = current_user.id
              ih.details["status_changed_by_user_name"] = current_user.full_name
              ih.save!
            end
          end
        end
      rescue ActiveRecord::RecordInvalid => exception
        render json: "Something Went Wrong", status: :unprocessable_entity
        return
      end
      get_insurance
      @insurances = @insurances.page(@current_page).per(@per_page)
      render json: @insurances, each_serializer: Api::V1::Warehouse::OldInsuranceSerializer
    else
      render json: "Please provide Valid id", status: :unprocessable_entity
    end
  end


  def get_dispositions
    lookup_key = LookupKey.find_by_code('WAREHOUSE_DISPOSITION')
    dispositions = lookup_key.lookup_values.where.not(original_code: ['Pending Disposition', 'Insurance', 'RTV', "Pending Transfer Out"]).order('original_code asc')
    policy_key = LookupKey.find_by_code('POLICY')
    policies = policy_key.lookup_values
    render json: {dispositions: dispositions.as_json(only: [:id, :original_code]), policies: policies.as_json(only: [:id, :original_code])}
  end

  def set_disposition
    disposition = LookupValue.find_by_id(params[:disposition])
    @insurances = Insurance.includes(:inventory).where(id: params[:insurance_ids])
    policy = LookupValue.find_by_id(params['policy']) if params['policy'].present?
    if @insurances.present? && disposition.present?
      @insurances.each do |insurance|
        begin
          ActiveRecord::Base.transaction do
            inventory = insurance.inventory
            insurance.details['disposition_set'] = true
            insurance.is_active = false
            insurance.resolution_date = Time.now
            inventory.disposition = disposition.original_code
            if disposition.original_code == 'Liquidation'
              insurance.details['policy_id'] = policy.id
              insurance.details['policy_type'] = policy.original_code
              inventory.details['policy_id'] = policy.id
              inventory.details['policy_type'] = policy.original_code
            end
            insurance_status_closed = LookupValue.find_by_code(Rails.application.credentials.insurance_status_insurance_closed)
            inventory.disposition = disposition.original_code
            insurance.status_id = insurance_status_closed.id
            insurance.status = insurance_status_closed.original_code
            inventory.save
            if insurance.save!
              ih = insurance.insurance_histories.new(status_id: insurance.status_id)
              ih.details = {}
              key = "#{insurance.status.try(:downcase).try(:strip).split(' ').join('_')}_created_at"
              ih.details[key] = Time.now
              ih.details["status_changed_by_user_id"] = current_user.id
              ih.details["status_changed_by_user_name"] = current_user.full_name
              # ih.save! Commented because QA raises like this should not come
            end
            DispositionRule.create_bucket_record(disposition.original_code, inventory, 'Insurance', current_user.id)
          end
        rescue ActiveRecord::RecordInvalid => exception
          render json: "Something Went Wrong", status: :unprocessable_entity
          return
        end
      end

      get_insurance
      @insurances = @insurances.page(@current_page).per(@per_page)
      render json: @insurances, each_serializer: Api::V1::Warehouse::OldInsuranceSerializer
    else
      render json: "Please provide Valid Ids", status: :unprocessable_entity
    end
  end

  def create_dispatch_items
    insurances = Insurance.where(id: params[:insurance_ids])
    if insurances.present?
      begin
        ActiveRecord::Base.transaction do
          vendor_master = VendorMaster.find_by_vendor_code(params[:vendor_code])
          @insurance_order = InsuranceOrder.new(vendor_code: vendor_master.vendor_code)
          @insurance_order.order_number = "OR-Insurance-#{SecureRandom.hex(6)}"
          if @insurance_order.save!
            #Update Vendor Return
            insurances.update_all(insurance_order_id: @insurance_order.id)
            # Create Warehouse order
            warehouse_order_status = LookupValue.find_by_code(Rails.application.credentials.order_status_warehouse_pending_pick)
            warehouse_order = @insurance_order.warehouse_orders.new(distribution_center_id: insurances.first.distribution_center_id, vendor_code: params[:vendor_code], reference_number: @insurance_order.order_number)
            warehouse_order.client_id = insurances.last.inventory.client_id
            warehouse_order.status_id = warehouse_order_status.id
            warehouse_order.total_quantity = @insurance_order.insurances.count
            warehouse_order.save!

            #Create Ware house Order Items
            @insurance_order.insurances.each do |insurance|

              client_category = ClientSkuMaster.find_by_code(insurance.sku_code).client_category rescue nil
              warehouse_order_item = warehouse_order.warehouse_order_items.new
              warehouse_order_item.inventory_id = insurance.inventory_id
              warehouse_order_item.client_category_id = client_category.id rescue nil
              warehouse_order_item.client_category_name = client_category.name rescue nil
              warehouse_order_item.sku_master_code = insurance.sku_code
              warehouse_order_item.item_description = insurance.item_description
              warehouse_order_item.tag_number = insurance.tag_number
              warehouse_order_item.quantity = 1
              warehouse_order_item.status_id = warehouse_order_status.id
              warehouse_order_item.serial_number = insurance.inventory.serial_number
              warehouse_order_item.aisle_location = insurance.aisle_location
              warehouse_order_item.toat_number = insurance.toat_number
              warehouse_order_item.details = insurance.inventory.details
              warehouse_order_item.save!
            end
          end
        end
      rescue ActiveRecord::RecordInvalid => exception
        render json: "Something Went Wrong", status: :unprocessable_entity
        return
      end
      render json: {order_number: @insurance_order.order_number}
    else
      render json: "Please provide Valid VendorReturn Id", status: :unprocessable_entity
    end
  end

  def get_vendor_insurance
    @vendor_master = VendorMaster.joins(:vendor_types).where('vendor_types.vendor_type': 'Insurance').distinct
    render json: @vendor_master
  end

  private

  def get_insurance
    set_pagination_params(params)
    get_distribution_centers
    ids = @distribution_center.present? ? [@distribution_center.id] : current_user.distribution_centers.pluck(:id)
    @insurances = Insurance.joins(:inventory).where(distribution_center_id: ids, is_active: true, status: params['status']).order('insurances.updated_at desc')
    @insurances = @insurances.where("inventories.is_putaway_inwarded IS NOT false")
    @insurances = @insurances.where("lower(insurances.details ->> 'criticality') IN (?) ", params[:criticality]) if params['criticality'].present?
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
        @distribution_center_detail = distribution_center_user.details.select{|d| d["disposition"] == "Insurance" || d["disposition"] == "All"}.last
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
