class Api::V1::Store::ApprovalsController < ApplicationController

  def index
    set_pagination_params(params)
    approval_return_request = LookupValue.where("code = ?", Rails.application.credentials.return_request_pending_client_approval).first
    if approval_return_request.present?
      @return_requests = ReturnRequest.filter(filtering_params).where("status_id = ?", approval_return_request.try(:id)).order('updated_at desc').page(@current_page).per(@per_page)
      render json: @return_requests, meta: pagination_meta(@return_requests)
    else
      render json: "No Data Found", status: :unprocessable_entity
    end
  end

  def approved_requests
    set_pagination_params(params)
    approved_return_request = LookupValue.where("code = ?", Rails.application.credentials.return_request_pending_packaging).first
    if approved_return_request.present?
      @return_requests = ReturnRequest.filter(filtering_params).where("status_id = ?", approved_return_request).order('updated_at desc').page(@current_page).per(@per_page)
      render json: @return_requests, meta: pagination_meta(@return_requests)
    else
      render json: "No Data Found", status: :unprocessable_entity
    end
  end

  def approve_requests
    @requests = ReturnRequest.where(id: params["return_requests"])
    return_request_pending_packaging = LookupValue.where(code: Rails.application.credentials.return_request_pending_packaging).first
    inventory_status_store_pending_packaging = LookupValue.where(code: Rails.application.credentials.inventory_status_store_pending_packaging).first
    if @requests.present? && return_request_pending_packaging.present?
      @requests.each do |request|
        inventories = Inventory.where("details ->> 'return_request_number' = ?", request.request_number)
        inventories.each do |inventory|
          last_inventory_status = inventory.inventory_statuses.where(is_active: true).last
          new_inventory_status = last_inventory_status.dup
          new_inventory_status.status_id = inventory_status_store_pending_packaging.try(:id)
          new_inventory_status.is_active = true
          if new_inventory_status.save
            last_inventory_status.update(is_active: false)
            inventory.update(details: inventory.merge_details({"status" => inventory_status_store_pending_packaging.try(:original_code)}))
          end
        end
        request.update(status_id: return_request_pending_packaging.try(:id), details: request.merge_details({"approved_time" => Time.now.to_s, "approved_username" => current_user.try(:username)}))
      end
      render json: @requests, status: 200
    else
      render json: "No Data Found", status: :unprocessable_entity
    end
  end

  private
  def filtering_params
    params.slice(:request_number)
  end

end
