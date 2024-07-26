class Api::V1::Warehouse::ManualProcessesController < ApplicationController

  def bucket_movement
    raise CustomErrors.new "Can not perform this action!"
    errors = []
    disposition = LookupValue.find(params[:disposition])
    inventories = Inventory.where.not(status: 'Closed Successfully').where(id: params[:inventory_ids])
    status = get_status(disposition.original_code)
    if inventories.present? && disposition.present?
      inventories.each do |inventory|
        if inventory.disposition == disposition.original_code
          errors.push("Item #{inventory.tag_number} is already present in selected disposition")
          next
        end
        if check_for_errors(inventory)
          errors.push("Item #{inventory.tag_number} is already associated to lot and cant be sent for disposition")
          next
        end
        bucket = inventory.get_current_bucket
        inventory.update_attributes(status_id: status.id, status: status.original_code, disposition: disposition.original_code)
        bucket.update_attributes(is_active: false) if bucket.present?
        DispositionRule.create_bucket_record(inventory.disposition, inventory, "Inward", current_user.id)
      end
    else
      errors.push('Item Not Present') if inventories.blank?
      errors.push('Given Bucket Not Valid') if disposition.blank?
    end

    if errors.blank?
      render :json => {
        message: 'Success',
        status: 200
      }
    else
      render :json => {
        message: errors.flatten.join(', '),
        status: 302
      }
    end
  end

  def delete_item
    inventories = Inventory.where.not(status: 'Closed Successfully').where(id: params[:inventory_ids])
    inventories.each do |inventory|
      inventory.inventory_grading_details.delete_all
      inventory.inventory_statuses.delete_all
      inventory.inventory_documents.delete_all
      if inventory.gate_pass_inventory.inwarded_quantity > inventory.gate_pass_inventory.quantity
        inventory.gate_pass_inventory.update_attributes(inwarded_quantity: inventory.gate_pass_inventory.quantity)
        inventory.gate_pass_inventory.update_gate_pass_inventory_status
      end
      bucket = inventory.get_current_bucket
      inventory.details["reason_for_deletion"] = params["reason"]
      inventory.details["remark_for_deletion"] = params["remark"] if params["remark"].present?
      inventory.details["deleted_by_user_id"] = current_user.id
      inventory.details["deleted_by_user_name"] = current_user.full_name
      inventory.save
      inventory.delete

      if bucket.present?
        bucket.details["reason_for_deletion"] = params["reason"]
        bucket.details["remark_for_deletion"] = params["remark"] if params["remark"].present?
        bucket.details["deleted_by_user_id"] = current_user.id
        bucket.details["deleted_by_user_name"] = current_user.full_name
        bucket.save
        bucket.delete
      end
    end
    render :json => {
      message: 'Success',
      status: 200
    }
  end

  def get_dispositions
    lookup_key = LookupKey.find_by_code('WAREHOUSE_DISPOSITION')
    dispositions = lookup_key.lookup_values.where.not(original_code: ['Pending Transfer Out', 'RTV', 'Replacement']).order('original_code asc')
    render json: {dispositions: dispositions.as_json(only: [:id, :original_code])} 
  end


  def check_for_errors(item)
    bucket = item.get_current_bucket
    case item.disposition
    when 'Liquidation'
      return true if bucket.liquidation_order_id.present?
    when 'Redeploy'
      return true if bucket.redeploy_order_id.present?
    when 'RTV'
      return true if bucket.vendor_return_order_id.present?
    else
      return false
    end
  end

  private
  def get_status(disposition)
    inventory_status = ''
    case disposition
    when 'Liquidation'
      inventory_status = LookupValue.where(code: Rails.application.credentials.inventory_status_warehouse_pending_liquidation).first
    when 'RTV'
      inventory_status = LookupValue.where(code: Rails.application.credentials.inventory_status_warehouse_pending_rtv).first
    when 'Repair'
      inventory_status = LookupValue.where(code: Rails.application.credentials.inventory_status_warehouse_pending_repair).first
    when 'E-Waste'
      inventory_status = LookupValue.where(code: Rails.application.credentials.inventory_status_warehouse_pending_e_waste).first
    when 'Replacement'
      inventory_status = LookupValue.where(code: Rails.application.credentials.inventory_status_warehouse_pending_replacement).first
    when 'Brand Call-Log'
      inventory_status = LookupValue.where(code: Rails.application.credentials.inventory_status_warehouse_pending_brand_call_log).first
    when 'Insurance'
      inventory_status = LookupValue.where(code: Rails.application.credentials.inventory_status_warehouse_pending_insurance).first
    when 'Redeploy'
      inventory_status = LookupValue.where(code: Rails.application.credentials.inventory_status_warehouse_pending_redeploy).first
    when 'Pending Disposition'
      inventory_status = LookupValue.where(code: Rails.application.credentials.inventory_status_warehouse_pending_pending_disposition).first
    when 'Pending Transfer Out', 'Markdown'
      inventory_status = LookupValue.where(code: Rails.application.credentials.inventory_status_warehouse_pending_markdown).first
    when 'Restock'
      inventory_status = LookupValue.where(code: Rails.application.credentials.inventory_status_warehouse_pending_restock).first
    end
    return inventory_status
  end
end
