class Api::V1::Warehouse::StockTransfersController < ApplicationController

  def assign_disposition
    params[:selected_inventories].each do |i|
      inventory = Inventory.find(i["id"])
      inventory.update_attributes(disposition: params["disposition"])
      if params["disposition"] == LookupValue.where(code: Rails.application.credentials.warehouse_disposition_liquidation).first.try(:original_code)
        policy = LookupValue.find_by_id(params['policy']) if params['policy'].present?
        inventory.details['policy_id'] = policy.id
        inventory.details['policy_type'] = policy.original_code
        inventory.save
      end
      DispositionRule.create_bucket_record(params["disposition"], inventory, "Pending Issue Resolution", current_user.id)
    end

    fetch_inventories
    file_types = LookupKey.where(code: "RETURN_REASON_FILE_TYPES").last
    invoice_file_type = file_types.lookup_values.where(original_code: "Customer Invoice").last
    render json: @inventories, invoice_file_type: invoice_file_type.id

  end

  def transfer

    StockTransfer.transfer(params[:selected_inventories], params)

    fetch_inventories

    render json: @inventories
  end

  def update_rsto
    status = LookupValue.where("code = ?", Rails.application.credentials.inventory_status_warehouse_closed_successfully).first
    params["inventory_ids"].each do |id|
      inventory = Inventory.find(id)
      gate_pass = inventory.gate_pass
      inventory.details["rsto_number"] = params["rsto_number"] if params["rsto_number"].present?
      inventory.details["rsto_remarks"] = params["rsto_remarks"] if params["rsto_remarks"].present?
      inventory.details["grn_number"] = params["update_grn"] if params["update_grn"].present?
      inventory.details["grn_received_time"] = Time.now.to_s
      inventory.details["grn_received_user_id"] = current_user.id
      inventory.details["grn_received_user_name"] = current_user.username    
      inventory.save
      inventory.update_attributes(status_id: status.id, status: status.original_code)
      inventory.inventory_statuses.create(status_id: status.id, user_id: current_user.id,
      distribution_center_id: inventory.distribution_center_id, details: {"user_id" => current_user.id, "user_name" => current_user.username})
      gate_pass.update_status
      if params["files"].present?
        document_type = LookupValue.where(code: Rails.application.credentials.warehouse_order_file_types_rsto_document).first
        params["files"].each do |document|
          attachment = inventory.inventory_documents.new(document_name_id: document_type.id)
          attachment.attachment = document
          attachment.save
        end
      end
    end
    
    fetch_inventories

    render json: @inventories
  end
  
  private

  def fetch_inventories
    inventory_status = LookupValue.where("code = ?", Rails.application.credentials.inventory_status_warehouse_pending_issue_resolution).first
    distribution_centers_ids = @current_user.distribution_centers.pluck(:id)
    @inventories = Inventory.includes(:inventory_grading_details, :inventory_documents, :warehouse_order_items, :vendor_returns, :insurances).where(distribution_center_id: distribution_centers_ids, status_id: inventory_status.id).where("details ->> 'stock_transfer_order_number' is NULL").order('updated_at desc')  
    return @inventories
  end

end
