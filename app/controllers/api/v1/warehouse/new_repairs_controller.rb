class Api::V1::Warehouse::NewRepairsController < ApplicationController
  
  before_action -> { set_pagination_params(params) }, only: [:index, :index_new, :repair_dispatch_items]
  
  before_action :get_repairs, :search_by_tag_number, :search_by_an_article, :search_by_grade, :search_by_quote_percentage, :search_by_expected_revised_grade, :search_by_repair_type, :search_by_repair_status, :search_by_price, only: [:index_new, :get_filters_data]
  
  before_action :set_repairs, only: [:update_pending_quotation, :update_repair_details, :create_dispatch_items, :update_details, :update_disposition, :update_disposition_item, :reject_disposition_item]

  before_action :get_repair, only: :show

  before_action :get_dispatch_items, :search_items_by_tag_number, :search_items_by_repair_order, :search_items_by_status, :search_items_by_repair_vendor, only: :repair_dispatch_items
  
  before_action :get_dispatch_item, only: :repair_dispatch_item
  # GET /api/v1/warehouse/new_repairs
  def index
    get_distribution_centers
    ids = @distribution_center.present? ? [@distribution_center.id] : current_user.distribution_centers.pluck(:id)
    @repairs = Repair.dc_filter(ids).includes(:repair_histories, :repair_attachments, inventory: :inventory_grading_details).where(is_active: true, status: params['status']).order('repairs.updated_at desc')
    # @repairs = @repairs.joins(:inventory).where("inventories.is_putaway_inwarded IS NOT false")
    if current_user.roles.last.name == "Default User"
      @items = check_user_accessibility(@repairs, @distribution_center_detail)
      @repairs = @repairs.where(id: @items.pluck(:id)).order('updated_at desc')
    end
    @repairs = @repairs.where("lower(repairs.details ->> 'criticality') IN (?) ", params[:criticality]) if params['criticality'].present?
    @repairs = @repairs.page(@current_page).per(@per_page)
    render json: @repairs, meta: pagination_meta(@repairs)
  end

  def index_new
    @repairs = @repairs.page(@current_page).per(@per_page)
    render json: @repairs, meta: pagination_meta(@repairs)
  end

  def update_pending_quotation
    Repair.transaction do
      pending_quotation_validation
      update_repair_records
      render json: { message: "#{@repairs.count} item(s) moved to Pending Repair Approval"}
    end
  end

  #? This will be used in Pending Repair Approval and Pending Repair Tab
  def update_details
    Repair.transaction do
      update_repair_records
      render json: { message: @message}
    end
  end

  def show
    render json: @repair
  end

  # GET /api/v1/warehouse/return_to_vendor/get_vendor_master
  def get_vendor_master
    if params[:query].present?
      @vendor_masters = VendorMaster.joins(:vendor_types).where("lower(vendor_name) LIKE ? OR lower(vendor_code) LIKE ?", '%'+params[:query].to_s.downcase+'%', '%'+params[:query].to_s.downcase+'%').distinct.limit(10)
    else
      @vendor_masters = VendorMaster.joins(:vendor_types).distinct.limit(10)
    end
    render json: @vendor_masters
  end

  #^ GET /api/v1/warehouse/new_repairs/repair_dispatch_items
  def repair_dispatch_items
    if @warehouse_order_items.present?
      @warehouse_order_items = @warehouse_order_items.page(@current_page).per(@per_page)
      render json: @warehouse_order_items, each_serializer: Api::V1::Warehouse::RepairWarehouseOrderItemSerializer, meta: pagination_meta(@warehouse_order_items) 
    else
      render json: @warehouse_order_items,  meta: pagination_meta(@warehouse_order_items) 
    end
  end

  def update_disposition
    raise CustomErrors.new "Invalid ID." if @repairs.blank?
    raise CustomErrors.new "Disposition can not be blank!" if repair_params[:disposition].blank?
    
    @repairs.update_all(assigned_disposition: repair_params[:disposition], assigned_id: current_user.id)

    # TODO Need Rule Engine method to check rule is created for a bucket - Sreejith
    #@repairs.each do |repair|
    #  #& It will create approval request for current insurance record
    #  details = {}
    #  ApprovalRequest.create_approval_request(object: repair, request_type: 'repair', request_amount: repair.repair_amount, details: details)
    #end
     
    render json: { message: "Admin successfully notified for Disposition Approval" }
  end

  def get_dispositions
    lookup_key = LookupKey.find_by_code('WAREHOUSE_DISPOSITION')
    dispositions = lookup_key.lookup_values.where(original_code: ['Liquidation', 'Restock', 'Markdown']).order('original_code asc')
    policy_key = LookupKey.find_by_code('POLICY')
    policies = policy_key.lookup_values
    render json: {dispositions: dispositions.as_json(only: [:id, :original_code]), policies: policies.as_json(only: [:id, :original_code])}
  end

  def get_filters_data
    #& Formmating key values
    tab_statuses = Repair.tab_statuses.collect{ |d| {id: d[1], name: d[0].humanize} }
    expected_revised_grades = Repair.expected_revised_grades.collect{ |d| {id: d[1], name: d[0].humanize} }
    repair_types = Repair.repair_types.collect{ |d| {id: d[1], name: d[0].humanize} }
    repair_statuses = Repair.repair_statuses.collect{ |d| {id: d[1], name: d[0].humanize} }
    repair_filter_status = [{id: Repair.repair_statuses["repaired"], name: "Repaired"}, {id: Repair.repair_statuses["not_repaired"], name: "Not repaired"}]
    grades = [{id: 'A', name: 'A'}, { id: 'B', name: 'B'}, {id: 'C', name: 'C'}, {id: 'D', name: 'D'}, {id: 'AA', name: 'AA'}, {id: 'Not Tested', name: 'Not Tested'} ]
    price = @repairs.pluck(:item_price).compact.sum
    min_price = price.min rescue 0
    max_price = price.max rescue 0

    #& Rendering data
    render json: {tab_status: tab_statuses, expected_revised_grade: expected_revised_grades, repair_type: repair_types, repair_statuse: repair_statuses, repair_filter_status: repair_filter_status, grades: grades, min_price: min_price, max_price: max_price}
  end

  def search_item
    set_pagination_params(params)
    get_distribution_centers
    ids = @distribution_center.present? ? [@distribution_center.id] : current_user.distribution_centers.pluck(:id)
    search_param = params['search'].split(',').collect(&:strip).flatten
    @repairs = Repair.where(status: params['status'], is_active: true, distribution_center_id: ids).where("lower(repairs.#{params['search_in']}) IN (?) ", search_param.map(&:downcase))
    # @repairs = @repairs.joins(:inventory).where("inventories.is_putaway_inwarded IS NOT false")
    @repairs = @repairs.where("lower(repairs.details ->> 'criticality') IN (?) ", params[:criticality]) if params['criticality'].present?
    @repairs = @repairs.page(@current_page).per(@per_page)
    render json: @repairs, meta: pagination_meta(@repairs)
  end

  # PUT /api/v1/warehouse/new_repairs/:id/update_repair_details
  def update_repair_details 
      repair_params = params[:repair_details]
      current_status = repair_params[:status]
      current_status_id = LookupValue.find_by(original_code: current_status).try(:id)
      next_status = next_status(current_status, repair_params[:repair_approval])
      next_status_id = LookupValue.find_by(original_code: next_status).try(:id)
      errors = []
      @repairs.each do |repair|
        if repair_params[:files].present?
          repair_params[:files].each do |file|
            repair.repair_attachments.create(attachment_file: file, attachment_type: current_status , attachment_type_id: current_status_id )
          end
        end

        repair.email_date = repair_params[:email_date] if repair_params[:email_date].present?
        repair.repair_location = repair_params[:repair_location] if repair_params[:repair_location].present?
        repair.rgp_number = repair_params[:rgp_number] if repair_params[:rgp_number].present?
        repair.repair_date = repair_params[:repair_date] if repair_params[:repair_date].present?
        repair.repair_amount = repair_params[:repair_amount] if repair_params[:repair_amount].present?
        repair.authorized_by = repair_params[:authorized_by] if repair_params[:authorized_by].present?
        repair.pending_initiation_remark = repair_params[:pending_initiation_remark] if repair_params[:pending_initiation_remark].present?
        repair.pending_quotation_remark = repair_params[:pending_quotation_remark] if repair_params[:pending_quotation_remark].present?
        repair.pending_approval_remark = repair_params[:pending_approval_remark] if repair_params[:pending_approval_remark].present?
        repair.pending_repair_remark = repair_params[:pending_repair_remark] if repair_params[:pending_repair_remark].present?
        repair.pending_disposition_remark = repair_params[:pending_disposition_remark] if repair_params[:pending_disposition_remark].present?
        repair.pending_repair_rgp_number = repair_params[:pending_repair_rgp_number] if repair_params[:pending_repair_rgp_number].present?
        repair.pending_repair_location = repair_params[:pending_repair_location] if repair_params[:pending_repair_location].present?
        repair.authorization_user_id = current_user.id
        if current_status == "Pending Repair,Pending Repair Completion"
          if repair_params[:repair_date].present?
            repair.status = next_status
            repair.status_id = next_status_id
          end
        else
          repair.status = next_status
          repair.status_id = next_status_id

          #! Don't know when will be using write off - NEED to check
          if current_status == "Pending Repair Approval"
            hash_data = [{ inventory_id: repair.inventory_id, stage_name: :repair_cost, vendor_code: VendorMaster.last(rand(1..50)).first.vendor_code, note_type: :debit, approval_reference_number: params[:approval_ref_number].to_s, claim_amount: repair.repair_amount, cost_type: :repair_cost, tab_status: :cost }]
            begin
              ThirdPartyClaim.create_thrid_party_claim(hash_data) 
            rescue => exc
              raise CustomErrors.new "#{exc.message}"
            end
          end
        end
        
        repair.resolution_date = Time.now if (next_status == LookupValue.find_by(code: Rails.application.credentials.repair_status_pending_repair_grade).original_code || next_status == LookupValue.find_by(code: Rails.application.credentials.repair_status_pending_repair_disposition).original_code)
        if repair.save
          repair.create_history(current_user.id) if current_status != "Pending Repair,Pending Repair Completion" || (current_status == "Pending Repair,Pending Repair Completion" && repair_params[:repair_date].present?)
        else
          error.push(repair.errors)
        end
      end
     
       
    if errors.blank?
      render json: @repairs
    else
      render json: errors.flatten, status: :unprocessable_entity
    end
  end

  def reject_disposition_item
    @repairs.update_all(assigned_disposition: nil, assigned_id: nil)
    render json: { message: "Item set for disposition rejected successfully" }
  end

  def update_disposition_item

    get_current_and_next_status
    lookup_key = LookupKey.find_by_code('WAREHOUSE_DISPOSITION')

    if @repairs.blank?
      render json: "Please Provide Valid Repair Ids", status: :unprocessable_entity 
    else
      assigned_disposition = ""
      @repairs.each do |repair|

        @disposition = lookup_key.lookup_values.find_by_original_code(repair.assigned_disposition)
        assigned_disposition = repair.assigned_disposition
        raise CustomErrors.new "Assigned disposition is blank for repair" if @disposition.blank?

        repair.update(
          details_disposition: @disposition.original_code,
          status: @next_status,
          status_id: @next_status_id,
          tab_status: :pending_disposition,
          is_active: false)

        #repair.create_history(current_user.id) if next_status != 'Pending Repair Disposition Set'
        repair.create_history(current_user.id) if @next_status != 'Pending Disposition'
        inventory = repair.inventory
        inventory.disposition = @disposition.original_code
        inventory.save

        DispositionRule.create_bucket_record(@disposition.original_code, repair.inventory, 'Repair', current_user.id)
      end
      
      #! Will uncomment if required
      #if params['files'].present?
      #  params['files'].each do |file|
      #    repair.repair_attachments.create(attachment_file: file, attachment_file_type: repair_params)
      #  end
      #end
      #render json:{ message: "Moved to assigned disposition bucket Successfully" }
      render json:{ message: "#{@repairs.count} item(s) moved to #{assigned_disposition} successfully" }
    end
  end  

  def create_dispatch_items

    validate_repair_items_to_dispatch
    
    begin
      ActiveRecord::Base.transaction do
        
        #& Step 1 -> Create Repair Order
        create_repair_order
        #& Step 2 -> Update Repair Record
        update_status_for_repairs
        #& Step 3 -> Create Warehouse Order
        create_warehouse_order
        #& Step 4 -> Create Warehouse Order Items and create history
        create_warehouse_order_items

      end
    rescue ActiveRecord::RecordInvalid => exception
      render json: exception.message, status: :unprocessable_entity
      return
    end
    render json: {message: "#{@repairs.count} item(s) moved to Dispatch Module"}
  end

  def repair_dispatch_item
    render json: @warehouse_order_item, serializer: Api::V1::Warehouse::Wms::WarehouseOrderItemSerializer
  end

  private

  #^ ---- Get Repair Data ------- 
  def repair_params
    params[:repair_details]
  end

  def set_repairs
    if params['status'].present?
      status = params['status']
    elsif repair_params['status'].present?
      status = repair_params['status']
    else
      status = 'Pending Quotation'
    end
    @repairs = (status == "Pending Quotation" ? Repair.where(id: repair_params[:ids].to_s.strip.split(',')) : Repair.where(id: repair_params[:ids]))
  end

  def get_repairs
    get_distribution_centers
    status = params['status'].blank? ? 'Pending Quotation' : params['status']
    user_roles = current_user.roles.pluck(:code)
    status_query = status == "Pending Repair" ? [status.to_s, 'Dispatch'] : [status]
    query = ["repairs.is_active = ? and repairs.status in (?) and repairs.distribution_center_id in (?)", true,  status_query, @distribution_center_ids]
    if params['status'] == 'Pending Disposition'
      if user_roles.include?('default_user')
        query[0] += " AND assigned_disposition is null"
      elsif user_roles.include?('central_admin')
        query[0] += " AND assigned_disposition is not null"
      end
    end
    @repairs = Repair.includes(:repair_histories, :distribution_center, :repair_attachments, inventory: :inventory_grading_details).where(query)&.select(:id, :distribution_center_id, :inventory_id, :tag_number, :details, :repair_amount, :sku_code, :item_description, :grade, :item_price, :repair_quote_percentage, :expected_revised_grade, :repair_type, :repair_status, :vendor_code, :assigned_disposition)&.order('repairs.updated_at desc')
  end

  def get_repair
    @repair = Repair.find(params[:id])
  end

  #^ ---- Filter methods -------
  def search_by_tag_number
    @repairs = @repairs.where(tag_number: params['tag_number'].to_s.gsub(" ", "").split(',')) if params['tag_number'].present?
  end

  def search_by_an_article
    @repairs = @repairs.where(sku_code: params['article_id']) if params['article_id'].present?
  end
  
  def search_by_grade
    @repairs = @repairs.where(grade: JSON.parse(params['grade'])) if params['grade'].present?
  end

  def search_by_quote_percentage
    #& Validation
    @repairs = @repairs.where(repair_quote_percentage: params['repair_quote_percentage'].to_f) if params['repair_quote_percentage'].present?
  end

  def search_by_price
    if params['price_min'].present? && params['price_max'].present?
      raise CustomErrors.new "Min or Max cannot be negative" if params['price_min'].to_f.negative? || params['price_max'].to_f.negative?
      raise CustomErrors.new "Min cannot be greater than Max"  if params['price_min'].to_f > params['price_max'].to_f
      @repairs = @repairs.where(item_price: (params['price_min'].to_f..params['price_max'].to_f))
    end
  end

  def search_by_expected_revised_grade
    @repairs = @repairs.where(expected_revised_grade: JSON.parse(params['expected_revised_grade']) ) if params['expected_revised_grade'].present?
  end

  def search_by_repair_type
    @repairs = @repairs.where(repair_type: JSON.parse(params['repair_type'])) if params['repair_type'].present?
  end

  def search_by_repair_status
    @repairs = @repairs.where(repair_status: JSON.parse(params['repair_status'])) if params['repair_status'].present?
  end

  def get_current_and_next_status
    repair_approval = repair_params[:repair_approval].present? ? repair_params[:repair_approval] : nil

    current_status = repair_params['status'].blank? ? "Pending Quotation" : repair_params['status']
    current_status_id = LookupValue.find_by(original_code: current_status).try(:id)
  
    @next_status = next_new_status(current_status, repair_approval)
    @next_status_id = LookupValue.find_by(original_code: @next_status).try(:id)
  end

  def update_repair_records
    @message = ""

    get_current_and_next_status
    
    repair_ids_and_status_validation

    @repairs.each do |repair|
  
      repair.status = @next_status
      repair.status_id = @next_status_id
      repair.vendor_code = repair_params['vendor_code'] if repair_params['vendor_code'].present?
      repair.repair_amount = repair_params['repair_quotation_value'] if repair_params['repair_quotation_value'].present?
      repair.repair_type = repair_params['repair_type'].to_i if repair_params['repair_type'].present?
      repair.expected_revised_grade = repair_params['expected_revised_grade'].to_i if repair_params['expected_revised_grade'].present?

      #& Setting Repair Tab status
      if repair_params['repair_approval'] == 'approve'
        repair.tab_status = :pending_repair
      elsif repair_params['repair_approval'] == 'reject'
        repair.tab_status = :pending_disposition
      else
        repair.tab_status = :pending_repair_approval
      end

      #& Setting Repair quote percentage
      if repair.repair_amount.to_f > 0 && repair.item_price.to_f > 0
        repair.repair_quote_percentage = ((repair.repair_amount.to_f/repair.item_price.to_f) * 100.to_f).round(2) 
      end

      if repair_params['status'].to_s.strip == 'Pending Repair Approval'
        hash_data = [{ inventory_id: repair.inventory_id, stage_name: :repair_cost, vendor_code: (repair.vendor_code rescue VendorMaster.last(rand(1..50)).first.vendor_code), note_type: :debit, approval_reference_number: params[:approval_ref_number].to_s, claim_amount: repair.repair_amount, cost_type: :repair_cost, tab_status: :cost }]
        begin
          ThirdPartyClaim.create_thrid_party_claim(hash_data) 
        rescue => exc
          raise CustomErrors.new "#{exc.message}"
        end

        raise CustomErrors.new "Repair Approval be blank cannot be blank" if repair_params['repair_approval'].blank?
      end

      #& Setting Repair Status
      if repair_params['status'].to_s.strip == 'Pending Repair'
        raise CustomErrors.new "Repair Status be blank cannot be blank" if repair_params['repair_status'].blank?
        repair.repair_status = repair_params['repair_status'].to_i
        repair.request_to_grade = true
      end
        
      #& Updating repair record
      repair.save!
    
      #& Storing the file attachment
      if params['file'].present?
        repair.update_document({file: params['file']})
      end

      #& Creating repair history
      repair.create_history(current_user.id)

      unless repair_params['status'].to_s.strip == 'Pending Repair' || repair_params['status'].to_s.strip == 'Pending Disposition'
        repair.update_inventory_status(@next_status)
      end
    end
    
    if repair_params['status'].to_s.strip == 'Pending Repair Approval'
      if repair_params['repair_approval'] == 'approve'
        @message = "#{@repairs.count} item(s) moved to Pending Repair"
      elsif repair_params['repair_approval'] == 'reject'
        @message = "#{@repairs.count} item(s) moved to Pending Disposition"
      end
    elsif repair_params['status'].to_s.strip == 'Pending Repair'
      @message = "#{@repairs.count} item(s) moved to Grading Module"
    end

  end

  def repair_ids_and_status_validation
    raise CustomErrors.new "repair ids cannot be blank cannot be blank" if repair_params['ids'].blank?
    raise CustomErrors.new "status cannot be blank cannot be blank" if repair_params['status'].blank?
  end

  def pending_quotation_validation
    repair_ids_and_status_validation
    raise CustomErrors.new "vendor cannot be blank" if repair_params['vendor_code'].blank?
    raise CustomErrors.new "Repair quotation value cannot be blank" if repair_params['repair_quotation_value'].blank?
    raise CustomErrors.new "Repair quotation value cannot be negative" if repair_params['repair_quotation_value'].present? && repair_params['repair_quotation_value'].to_f.negative?
    raise CustomErrors.new "Repair quotation value cannot contain letters" if repair_params['repair_quotation_value'].present? && repair_params['repair_quotation_value'].to_s.count("a-zA-Z") > 0
    raise CustomErrors.new "Repair type cannot be blank" if repair_params['repair_type'].blank?
    raise CustomErrors.new "Expected revised grade cannot be blank" if repair_params['expected_revised_grade'].blank?
  end

  def validate_repair_items_to_dispatch
    #& Validations
    raise CustomErrors.new "vendor_code cannot be blank" if repair_params[:vendor_code].blank?
    raise CustomErrors.new "ids cannot be blank" if repair_params[:ids].blank?
    raise CustomErrors.new "status cannot be blank" if repair_params[:status].blank?
    
    #& Find Repairs
    wrong_repairs_records = @repairs.where("repair_type = #{Repair.repair_types['location']} or repair_type is null")
    @repairs = @repairs.where(repair_type: :service_center)
    raise CustomErrors.new "Repair type location cannot be dispatched" if wrong_repairs_records.present?
  end

  def create_repair_order
    vendor_master = VendorMaster.find_by_vendor_code(repair_params[:vendor_code])
    @repair_order = RepairOrder.new(vendor_code: vendor_master.vendor_code)
    @repair_order.order_number = "OR-Repair-#{SecureRandom.hex(6)}"
    @repair_order.save!
  end

  def update_status_for_repairs
    get_current_and_next_status
    @repairs.update_all(repair_order_id: @repair_order.id, status: @next_status, status_id: @next_status_id, tab_status: :dispatch, repair_status: :pending_dispatch_to_service_center)
  end

  def create_warehouse_order
    @warehouse_order_status = LookupValue.find_by_code(Rails.application.credentials.dispatch_status_pending_pickup)
    @warehouse_order = @repair_order.warehouse_orders.new(
      distribution_center_id: @repairs.first.distribution_center_id, 
      vendor_code: @repair_order.vendor_code, 
      reference_number: @repair_order.order_number,
      client_id: @repairs.last.client_id,
      status_id: @warehouse_order_status.id,
      total_quantity: @repair_order.repairs.count
    )
    @warehouse_order.save!
  end

  def create_warehouse_order_items
    @repair_order.repairs.each do |repair|
      #& Creating repair history
      repair.create_history(current_user.id)
      #repair.update_inventory_status(@next_status)
      
      client_category = ClientSkuMaster.find_by_code(repair.sku_code).client_category rescue nil
      @warehouse_order_item = @warehouse_order.warehouse_order_items.new(
        inventory_id: repair.inventory_id,
        client_category_id: (client_category.id rescue nil),
        client_category_name: (client_category.name rescue nil),
        sku_master_code: repair.sku_code,
        item_description: repair.item_description,
        tag_number: repair.tag_number,
        quantity: 1,
        status_id: @warehouse_order_status.id,
        status: @warehouse_order_status.original_code,
        serial_number: repair.serial_number,
        aisle_location: repair.aisle_location,
        toat_number: repair.toat_number,
        details: repair.inventory.details,
        amount: repair.repair_amount
      )
      @warehouse_order_item.save!
    end
  end

  #^ ------------ Dispatch Items Collection with filters -------------
  def get_dispatch_items
    warehouse_orders = WarehouseOrder.where(orderable_type: "RepairOrder").select(:id)
    return @warehouse_order_items if warehouse_orders.blank?
    if warehouse_orders.present?
      @warehouse_order_items = WarehouseOrderItem.includes(:inventory, :warehouse_order).where.not(tab_status: [:pending_disposition, :not_found_items]).where(warehouse_order_id: warehouse_orders.pluck(:id))&.select(:id, :inventory_id, :item_description, :tag_number, :status, :warehouse_order_id, :amount, :tab_status, :ord)&.order("warehouse_order_items.updated_at desc")
    end
  end

  def get_dispatch_item
    @warehouse_order_item = WarehouseOrderItem.find(params[:id])
  end

  def search_items_by_tag_number
    @warehouse_order_items = @warehouse_order_items.where(tag_number: params[:tag_number].to_s.gsub(" ", "").split(',')) if params[:tag_number].present?
  end

  def search_items_by_repair_order
    @warehouse_order_items = @warehouse_order_items.joins(:warehouse_order).where("warehouse_orders.reference_number = ?", params['repair_order']) if params['repair_order'].present? 
  end

  def search_items_by_status
    @warehouse_order_items = @warehouse_order_items.where(tab_status: params['status']) if params['status'].present?
  end

  def search_items_by_repair_vendor
    @warehouse_order_items = @warehouse_order_items.joins(:warehouse_order).where("warehouse_orders.vendor_code IN (?)", JSON.parse(params['repair_vendor_code'])) if params['repair_vendor_code'].present? 
  end

  #only allow a trusted parameters
  # def repair_params
  #   rep_params = params.require(:repair_details).permit(:email_date, :repair_location, :rgp_number, :status, 
  #     :repair_date, :repair_amount, :authorized_by, :pending_initiation_remark, :pending_quotation_remark, 
  #     :pending_approval_remark, :pending_repair_remark, :pending_disposition_remark, :repair_approval, files: [])    
  #   rep_params[:authorization_user_id] = current_user.id  if rep_params[:authorized_by].present?
  #   rep_params
  # end


  def next_status(status, repair_approval)
    repair_approval ||= nil
    pri = LookupValue.find_by(code: Rails.application.credentials.repair_status_pending_repair_initiation).original_code
    prq = LookupValue.find_by(code: Rails.application.credentials.repair_status_pending_repair_estimate).original_code
    pra = LookupValue.find_by(code: Rails.application.credentials.repair_status_pending_repair_approval).original_code
    pr  = LookupValue.find_by(code: Rails.application.credentials.repair_status_pending_repair).original_code
    prg = LookupValue.find_by(code: Rails.application.credentials.repair_status_pending_repair_grade).original_code 
    prd = LookupValue.find_by(code: Rails.application.credentials.repair_status_pending_repair_disposition).original_code
    pds = LookupValue.find_by(code: Rails.application.credentials.repair_status_pending_repair_disposition_set).original_code
    status = status.to_s.split(",")
    if(status.include?(pri))
      prq
    elsif(status.include?(prq))
      pra
    elsif(status.include?(pra) &&  repair_approval == "approve")
      pr
    elsif(status.include?(pra) &&  repair_approval == "reject")
      LookupValue.find_by(code: Rails.application.credentials.repair_status_pending_redeployment).original_code
    elsif(status.include?(pr) || status.include?('Pending Repair'))
      prg
    elsif(status.include?(prd))
      pds
    else
      status
    end  
  end

  def next_new_status(par_status, repair_approval)
    repair_approval ||= nil
    pri = LookupValue.find_by(code: Rails.application.credentials.repair_status_pending_quotation).original_code
    prq = LookupValue.find_by(code: Rails.application.credentials.repair_status_pending_repair_approval).original_code
    pra = LookupValue.find_by(code: Rails.application.credentials.repair_status_pending_repair).original_code
    pr  = LookupValue.find_by(code: Rails.application.credentials.repair_status_dispatch).original_code
    prg = LookupValue.find_by(code: Rails.application.credentials.repair_status_pending_disposition).original_code
    status = par_status.to_s.split(",")
    if(status.include?(pri))
      prq
    elsif(status.include?(prq)) 
      if repair_approval == "approve"
        pra
      else
        prg
      end
    elsif(status.include?(pra))
      pr  
    elsif(status.include?(prg))
      prg
    else
      par_status
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
        @distribution_center_detail = distribution_center_user.details.select{|d| d["disposition"] == "Repair" || d["disposition"] == "All"}.last
        if @distribution_center_detail.present?
          @distribution_center_ids = @distribution_center_detail["warehouse"].include?(0) ? DistributionCenter.ids : @distribution_center_detail["warehouse"]
          return
        end
      end
    else
      @distribution_center_ids = @distribution_center.present? ? [@distribution_center.id] : DistributionCenter.ids
    end
  end
  
end

# --- For creation of repair inventory -------------------------
# lkv = LookupValue.where("original_code = ?", "Pending Repair Initiation").first
# Inventory.where("disposition = ?","Repair").each do|inv|
#   Repair.create(distribution_center_id: inv.distribution_center_id,
#   inventory_id: inv.id,
#   details: inv.details[:disposition] = "Repair",  
#   tag_number: inv.tag_number,
#   details: inv.details,
#   status_id: lkv.id,
#   status: lkv.original_code)
# end
# ---------------------------------------------------------------
