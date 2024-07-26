class Api::V1::Warehouse::BrandCallLogsController < ApplicationController
  before_action :set_brand_call_log, only: [:show, :update_document]

  def index
    set_pagination_params(params)
    filter_brand_call_logs
    @brand_call_logs = @brand_call_logs.page(@current_page).per(@per_page)
    render json: @brand_call_logs, meta: pagination_meta(@brand_call_logs)
  end

  def show
    data = @brand_call_log.as_json(only: [:id, :tag_number, :grade, :brand, :sku_code, :item_description, :supplier, :order_number, :ticket_number, :item_price, :benchmark_price, :net_recovery, :recovery_percent])
    data[:ticket_date] = format_date(@brand_call_log.ticket_date)
    data[:inspection_date] = format_date(@brand_call_log.inspection_date.to_date) rescue ''
    data[:approved_date] = format_date(@brand_call_log.approved_date)
    data[:inspection_report] = {name: @brand_call_log.inspection_report&.file&.filename, url: @brand_call_log.inspection_report_url} if @brand_call_log.inspection_report.present?
    data[:required_documents] = @brand_call_log.get_required_documents
    render json: { brand_call_log: data }
  end
  
  def update_document
    begin
      BrandCallLog.transaction do
        message = @brand_call_log.update_document(params)
        if @brand_call_log.check_for_pending_bcl_ticket?
          @brand_call_log.update!(status: "pending_bcl_ticket")
          @brand_call_log.update_inventory_status("brand_call_log_status_pending_bcl_ticket", current_user)
        end
        
        render json: { message: message }
      end
    rescue Exception => message
      render json: { error: message.to_s }, status: 500
    end
  end
  
  def get_pending_documents
    brand_call_logs = get_call_logs("pending_information")
    all_docs = brand_call_logs.map{|i| i.pending_documents }
    pending_documents = Insurance.common_hashes all_docs
    pending_documents = pending_documents.map{|d| {field: d["field"].parameterize.underscore, label: d["field"], data_type: d["data_type"], is_mandatory: d["is_mandatory"]} }
    
    render json: { pending_documents: pending_documents }
  end
  
  def bulk_update_docs
    begin
      BrandCallLog.transaction do
        formatted_doc_hash = get_formatted_params(params)
        brand_call_logs = BrandCallLog.where("id in (#{formatted_doc_hash["ids"].to_s}) and status = 1")
        items_moved = 0
        brand_call_logs.each do |brand_call_log|
          formatted_doc_hash["documents"].each do |document|
            document = document.symbolize_keys
            brand_call_log.update_document(document)
          end
          if brand_call_log.check_for_pending_bcl_ticket?
            brand_call_log.update!(status: "pending_bcl_ticket")
            brand_call_log.update_inventory_status("brand_call_log_status_pending_bcl_ticket", current_user)
            items_moved += 1
          end
        end
        
        if items_moved > 0
          message = "#{items_moved} item(s) moved to Pending BCL Ticket."
        else
          message = "Documents updated successfully."
        end
        render json: { message: message }
      end
    rescue Exception => message
      render json: { error: message.to_s }, status: 500
    end
  end
  
  def update_ticket
    BrandCallLog.transaction do
      brand_call_logs = get_call_logs("pending_bcl_ticket")
      
      raise CustomErrors.new "Please fill the details." if (params[:ticket_date].blank? || params[:ticket_number].blank?)
      item_count = brand_call_logs.count
      brand_call_logs.each do |brand_call_log|
        brand_call_log.ticket_date = params[:ticket_date]
        brand_call_log.ticket_number = params[:ticket_number]
        brand_call_log.status = "pending_inspection"
        brand_call_log.save!
        brand_call_log.update_inventory_status("brand_call_log_status_pending_inspection", current_user)
      end
      
      render json: { message: "#{item_count} Item(s) moved to Pending Inspection" }
    end
  end
  
  def update_inspection_details
    BrandCallLog.transaction do
      brand_call_logs = BrandCallLog.where("id in (#{params[:ids].to_s})")
      raise CustomErrors.new "Invalid ID." if brand_call_logs.blank?
      
      raise CustomErrors.new "Please fill the details." if (params[:inspection_date].blank? || params[:inspection_report].blank?)
      item_count = brand_call_logs.count
      brand_call_logs.each do |brand_call_log|
        brand_call_log.update!(inspection_date: params[:inspection_date], inspection_report: params[:inspection_report], status: "pending_decision")
        brand_call_log.update_inventory_status("brand_call_log_status_pending_decision", current_user)
      end
      
      render json: { message: "#{item_count} Item(s) moved to Pending Decision" }
    end
  end
  
  def get_brand_decisions
    brand_decisions = ["RTV", "Replacement", "Discount", "Repair", "Reject"].map{|d| {id: d, code: d} }
    locations = [{id: "location", name: "In-House"}, {id: "service_center", name: "Service Center"}]
    render json: { brand_decisions: brand_decisions, locations: locations }
  end
  
  def update_approval_details
    BrandCallLog.transaction do
      brand_call_logs = get_call_logs("pending_decision")
      item_count = brand_call_logs.count
      brand_decision = params[:brand_decision]
      
      raise CustomErrors.new "Invalid Brand Decision" if brand_decision.blank?
      raise CustomErrors.new "Approval Reference Number can not be blank." if (params[:approval_ref_number].blank? and brand_decision != "Reject")

      claim_data = []
      brand_call_logs.each do |brand_call_log|
        update_params(brand_call_log)
        
        if (brand_decision == "RTV" || brand_decision == "Discount")
          stage_name = brand_call_log.brand_decision == "RTV" ? :rtv : :discount
          claim_data << { inventory_id: brand_call_log.inventory_id, stage_name: stage_name, vendor_code: brand_call_log.get_vendor_code || VendorMaster.last(rand(1..50)).first.vendor_code, note_type: :credit, approval_reference_number: params[:approval_ref_number], credit_debit_note_number: params[:credit_note_number], claim_amount: params[:credit_note_amount] || brand_call_log.item_price.to_f, tab_status: :recovery }
        end
      end
      ThirdPartyClaim.create_thrid_party_claim(claim_data) if not claim_data.blank?

      if (brand_decision == "Reject" || brand_decision == "Discount")
        brand_call_logs.each do |brand_call_log|
          brand_call_log.update!(status: "pending_disposition")
          brand_call_log.update_inventory_status("brand_call_log_status_pending_disposition", current_user)
        end
        message = "#{item_count} item(s) moved to Pending Disposition"
      else
        disposition = brand_decision
        brand_call_logs.each do |brand_call_log|
          brand_call_log.set_disposition(disposition, current_user)
        end
        message = "#{item_count} item(s) moved to #{disposition} successfully."
      end

      render json: { message: message }
    end
  end

  def get_dispositions
    dispositions = if params[:salvage_action] == "reject"
      ["No Action", "Repair", "Markdown", "Liquidation"].map{|d| {id: d, code: d} }
    else
      ["Repair", "Markdown", "Liquidation"].map{|d| {id: d, code: d} }
    end
    render json: { dispositions: dispositions }
  end
  
  def update_disposition
    BrandCallLog.transaction do
      brand_call_logs = BrandCallLog.includes(:inventory, :distribution_center).where(id: params[:ids], status: "pending_disposition")
      raise CustomErrors.new "Invalid ID." if brand_call_logs.blank?
      raise CustomErrors.new "Disposition can not be blank!" if params[:disposition].blank?
      
      brand_call_logs.each do |brand_call_log|
        begin
          brand_call_log.assigned_disposition = params[:disposition]
          brand_call_log.assigner_id = current_user.id
          brand_call_log.save!
        rescue => exc
          raise CustomErrors.new exc
        end

        inventory = brand_call_log.inventory
        dc_name = brand_call_log.distribution_center&.name
        #& It will create approval request for current brand_call_log record
        details = {
          tag_number: brand_call_log.tag_number,
          article_number: brand_call_log.sku_code,
          brand: inventory.details['brand'],
          mrp: inventory.item_price.to_f,
          description: inventory.item_description,
          requested_by: current_user.full_name,
          grade: brand_call_log.grade,
          inventory_created_date: format_date(inventory.created_at.to_date),
          requested_date: format_date(Date.current),
          requested_disposition: params[:disposition],
          distribution_center: dc_name,
          subject: "Approval required for Disposition of #{inventory.sku_code} in RPA:#{dc_name}",
          rims_url: get_host,
          rule_engine_type: get_rule_engine_type
        }
        ApprovalRequest.create_approval_request(object: brand_call_log, request_type: 'brand_call_log', request_amount: inventory.item_price, details: details)
      end

      render json: { message: "Admin successfully notified for Disposition Approval" }
    end
  end
  
  def set_disposition
    begin
      ActiveRecord::Base.transaction do
        brand_call_logs = BrandCallLog.includes(:inventory).where(id: params[:ids], status: "pending_disposition")
        raise CustomErrors.new "Invalid ID." if brand_call_logs.blank?
        brand_call_logs_count = brand_call_logs.count

        raise CustomErrors.new "Disposition can not be blank!" if (params[:disposition_action] == "reject" and params[:disposition].blank?)
        
        if (params[:disposition_action] == "reject" and params[:disposition] == "No Action")
          brand_call_logs.each do |brand_call_log|
            brand_call_log.update(assigned_disposition: nil)
            brand_call_log.approval_requests.status_sent.update_all(status: :rejected)
          end
          message = "#{brand_call_logs_count} item(s) rejected successfully."
        else
          assigned_dispositions = []
          brand_call_logs.each do |brand_call_log|
            assigned_disposition = params[:disposition] || brand_call_log.assigned_disposition
            brand_call_log.set_disposition(assigned_disposition, current_user)
            assigned_dispositions << assigned_disposition
          end
          message = "#{brand_call_logs_count} item(s) moved to #{assigned_dispositions.uniq.join(',')} successfully."
        end
        
        render json: { message: message }
      end
    rescue Exception => message
      render json: { error: message.to_s }, status: 500
      return
    end
  end
  

  private
  
  def set_brand_call_log
    @brand_call_log = BrandCallLog.find_by(id: params[:id])
  end
  
  def filter_brand_call_logs
    @brand_call_logs = BrandCallLog.includes(:inventory).where(is_active: true, status: params[:status]).order('brand_call_logs.updated_at desc')
    dc_ids = @distribution_center.present? ? [@distribution_center.id] : current_user.distribution_centers.select(:id)
    @brand_call_logs = @brand_call_logs.where(distribution_center_id: dc_ids)
    
    if params[:status] == "pending_disposition"
      filter_disposition_logs
      user_roles = current_user.roles.pluck(:code)
      if user_roles.include?('default_user')
        @brand_call_logs = @brand_call_logs.where(assigned_disposition: nil)
      elsif user_roles.include?('central_admin')
        @brand_call_logs = @brand_call_logs.where.not(assigned_disposition: nil)
      end
    end
    # @brand_call_logs = @brand_call_logs.where("inventories.is_putaway_inwarded IS NOT false")
    if params[:tag_number].present?
      tag_numbers = params[:tag_number].split(',').collect(&:strip).flatten
      @brand_call_logs = @brand_call_logs.where(tag_number: tag_numbers)
    end
    @brand_call_logs = @brand_call_logs.where(brand: params[:brand]) if params[:brand].present?
    @brand_call_logs = @brand_call_logs.where(supplier: params[:supplier]) if params[:supplier].present?
    @brand_call_logs = @brand_call_logs.where(sku_code: params[:sku_code]) if params[:sku_code].present?
    @brand_call_logs = @brand_call_logs.where(ticket_number: params[:ticket_number]) if params[:ticket_number].present?
  end
  
  def filter_disposition_logs
    @brand_call_logs = @brand_call_logs.where(grade: params[:grade]) if params[:grade].present?
    @brand_call_logs = @brand_call_logs.where("benchmark_price >= ?", params[:min_benchmark_price].to_f) if !params[:min_benchmark_price].blank?
    @brand_call_logs = @brand_call_logs.where("benchmark_price <= ?", params[:max_benchmark_price].to_f) if !params[:max_benchmark_price].blank?
    @brand_call_logs = @brand_call_logs.where("net_recovery >= ?", params[:min_net_recovery].to_f) if !params[:min_net_recovery].blank?
    @brand_call_logs = @brand_call_logs.where("net_recovery <= ?", params[:max_net_recovery].to_f) if !params[:max_net_recovery].blank?
    @brand_call_logs = @brand_call_logs.where("recovery_percent >= ?", params[:min_net_recovery_percent].to_f) if !params[:min_net_recovery_percent].blank?
    @brand_call_logs = @brand_call_logs.where("recovery_percent <= ?", params[:max_net_recovery_percent].to_f) if !params[:max_net_recovery_percent].blank?
  end
  
  def get_call_logs(status)
    brand_call_logs = BrandCallLog.where(id: params[:ids], status: status)
    raise CustomErrors.new "Invalid ID." if brand_call_logs.blank?
    
    brand_size = brand_call_logs.pluck(:brand).uniq.size
    supplier_size = brand_call_logs.pluck(:supplier).uniq.size
    raise CustomErrors.new "Brand and Supplier should be same" if (brand_size > 1 || supplier_size > 1)
    
    brand_call_logs
  end
  
  def get_formatted_params params
    final_hash = {}
    new_data = []
    
    params.except("ids", "action", "controller").each do |key, values_arr|
      index = 0
      values_arr.each do |hash_d|
        
        if new_data[index].present?
          new_data[index].merge!({key => hash_d[1]})
        else
          new_data[index] = {}
          new_data[index][key] = hash_d[1]
        end
        index += 1
      end  
    end
    
    final_hash["ids"] = params[:ids]
    final_hash["documents"] = new_data
    final_hash
  end
  
  def update_params(brand_call_log)
    brand_call_log.assign_attributes(brand_decision: params[:brand_decision], approval_ref_number: params[:approval_ref_number], credit_note_number: params[:credit_note_number])
    data = {"credit_note_amount" => params[:credit_note_amount], "discount_value" => params[:discount_value], "discount_percentage" => params[:discount_percentage], "repair_type" => params[:repair_type]}
    brand_call_log.details ||= {}
    brand_call_log.details.merge!(data)
    brand_call_log.net_recovery = params[:credit_note_amount].to_f
    brand_call_log.recovery_percent = brand_call_log.get_recovery_percent
    brand_call_log.save!
  end

end
