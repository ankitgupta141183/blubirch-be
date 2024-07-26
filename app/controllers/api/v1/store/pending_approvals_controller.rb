class Api::V1::Store::PendingApprovalsController < ApplicationController

  def index
    set_pagination_params(params)
    return_request_pending_store_approval = LookupValue.where(code: Rails.application.credentials.return_request_pending_store_approval).first
    if return_request_pending_store_approval.present?
      @return_requests = ReturnRequest.filter(filtering_params).includes(:distribution_center, :client, :customer_return_reason, :invoice).where("status_id = ?", return_request_pending_store_approval.id).references(:distribution_center, :client, :customer_return_reason, :invoice).reorder(updated_at: :desc).page(@current_page).per(@per_page)
      render json: @return_requests, meta: pagination_meta(@return_requests)
    else
      render json: "No Data Found", status: :unprocessable_entity
    end
  end

  def approve_request
    @return_requests = ReturnRequest.where("id in (?)", params['return_requests'])
    return_request_pending_client_approval = LookupValue.where(code: Rails.application.credentials.return_request_pending_client_approval).first
    if @return_requests.present? && return_request_pending_client_approval.present?
      @return_requests.each do |request|
        request.update(status_id: return_request_pending_client_approval.try(:id), details: request.merge_details({"approval_sent_date" => Time.now.to_s, "approval_sent_username" => current_user.try(:username)}))
      end
      render json: @return_requests
    else
      render json: "No Data Found", status: :unprocessable_entity
    end
  end

  def fetch_inventories
    if params[:return_request_number].present?
      set_pagination_params(params)
      if !params[:sku_code].present?
        @inventory = Inventory.where("details ->> 'return_request_number' in (?)",params[:return_request_number]).page(@current_page).per(@per_page)
        render json: @inventory, meta: pagination_meta(@inventory)
      elsif params[:sku_code].present? 
        @inventory = Inventory.where("details ->> 'return_request_number' in (?) and details ->> 'sku' in (?)",params[:return_request_number],params[:sku_code]).page(@current_page).per(@per_page)
        render json: @inventory, meta: pagination_meta(@inventory)
      else
        render json: "No Data Found", status: :unprocessable_entity
      end 
    end
  end

  def reduce_inventory_count
    @inventory = Inventory.where(id: params[:inventory_id]).first rescue nil 
    count = (@inventory.details["quantity"].to_i - 1) rescue nil
    if @inventory.present? and count >= 0
      Inventory.where(id: params[:inventory_id]).update_all("details = jsonb_set(details, '{quantity}', to_json(#{count}::int)::jsonb )")
      InventoryStatus.where("inventory_id = ?",params[:inventory_id]).update_all("details = jsonb_set(details, '{quantity}', to_json(#{count}::int)::jsonb )")
      InventoryGradingDetail.where("inventory_id = ?",params[:inventory_id]).update_all("details = jsonb_set(details, '{quantity}', to_json(#{count}::int)::jsonb )")
      InvoiceInventoryDetail.where("invoice_id = (?) and details ->> 'product_code_sku' in (?)",@inventory.details["invoice_id"],@inventory.details["product_code_sku"]).update_all(quantity: count)
      render json: count, status: 200
    else
      render json: {status: "error", code: 3000, message: "Can't find inventory"}
    end
  end

  def destroy_inventory
    @inventory = Inventory.where(id: params[:inventory_id]).first rescue nil
    total_inventory_count = ReturnRequest.where("request_number = ?",@inventory.details["return_request_number"]).first.details["total_inventories"].to_i rescue nil
    total_inventory_count = (total_inventory_count - @inventory.details["quantity"]) rescue nil
    if @inventory.present?
      Inventory.where(id: params[:inventory_id]).delete_all
      InventoryStatus.where("inventory_id = ?",params[:inventory_id]).delete_all
      InventoryGradingDetail.where("inventory_id = ?",params[:inventory_id]).delete_all
      PackedInventory.where("inventory_id = ?",params[:inventory_id]).delete_all
      invoice_inventory_detail = InvoiceInventoryDetail.where("invoice_id = (?) and details ->> 'product_code_sku' in (?)",@inventory.details["invoice_id"],@inventory.details["product_code_sku"]).first rescue nil     
      if invoice_inventory_detail.present?
        invoice_inventory_detail.return_quantity = (invoice_inventory_detail.return_quantity.to_i - 1) rescue nil
        invoice_inventory_detail.save! rescue nil
      end
      if total_inventory_count == 0
        ReturnRequest.where("request_number = ?",@inventory.details["return_request_number"]).delete_all  
        render json: {status: "success", message: "Successful deletion of inventory and return_request"}
      else
        ReturnRequest.where("request_number = ?",@inventory.details["return_request_number"]).update_all("details = jsonb_set(details, '{total_inventories}', to_json(#{total_inventory_count}::int)::jsonb )")
        render json: {status: "success", message: "Successful deletion of inventory"}
      end
    else
      render json: {status: "error", code: 3000, message: "Can't find inventory"}
    end
  end

  def set_reminder
    @customer_return_reason = CustomerReturnReason.where(name: params[:return_reason]).first
    @reminders = Reminder.where(customer_return_reason_id: @customer_return_reason.id).first
    escalation = @reminders.details['escalation']
    reminder_first = @reminders.details['reminder_1']
    reminder_second = @reminders.details['reminder_2']
    
    details = Hash.new
    details['return_reason'] = params['return_reason'] rescue nil
    details['invoice_no'] = params['invoice_number'] rescue nil
    details['rrn_no'] = params['rrn'] rescue nil
      

    if @customer_return_reason.present? and @reminders.present? and @reminders.approval_required
      details['approval_template_id'] = @reminders.details['approval_template_type_id']
      details['approve_email_id'] = @reminders.details['approval_to'] 
      details['copy_email_id'] = @reminders.details['copy_to'] 
      ReminderMailer.with(email_details: details).approval_email.deliver_now
    end

    if escalation.present? 
      escalation.each do |escalate|
        details['escalation_duration'] = escalate['escalation_duration']
        details['escalation_email_id'] = escalate['escalation_to']
        details['escalation_copy_email_id'] = escalate['escalation_copy_to'] 
        details['escalation_template_id'] = escalate['escalation_template_type_id']
        ReminderMailer.with(email_details: details).escalation_email.deliver_later(wait_until: details['escalation_duration'].to_i.days.from_now)
      end   
    end   
      
    if reminder_first.present?
      details['reminder_template_id'] = @reminders.details['reminder_template_type_id']
      details['reminder_email_id'] = @reminders.details['reminder_to']
      details['reminder_copy_email_id'] = @reminders.details['reminder_copy_to']
      details['reminder1_duration'] =  @reminders.details['reminder_1']
      details['reminder2_duration'] =  @reminders.details['reminder_2']
      
      ReminderMailer.with(email_details: details).reminder_email.deliver_later(wait_until: details['reminder1_duration'].to_i.days.from_now)
      
      if reminder_second.present?
        ReminderMailer.with(email_details: details).reminder_email.deliver_later(wait_until: (details['reminder1_duration'].to_i+details['reminder2_duration'].to_i).days.from_now)
      end
         
    end
  end

  private
  def filtering_params
    params.slice(:request_number)
  end

end