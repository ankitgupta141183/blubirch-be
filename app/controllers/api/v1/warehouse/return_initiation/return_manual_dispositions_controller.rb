class Api::V1::Warehouse::ReturnInitiation::ReturnManualDispositionsController < ApplicationController

  def index
    set_pagination_params(params)
    return_creation_pending_approval_status = LookupValue.where(code: Rails.application.credentials.return_creation_pending_approval_status).first
    pending_manual_dispositions = ReturnItem.where("status_id = ? and disposition is null", return_creation_pending_approval_status).page(@current_page).per(@per_page)
    render json: pending_manual_dispositions, meta: pagination_meta(pending_manual_dispositions)
  end

  def assign_disposition
    if params[:disposition_id].present?
      return_creation_disposition = LookupValue.where(id: params[:disposition_id]).first
      return_items = ReturnItem.where("id in (?)", params[:return_ids].split(","))
      if return_items.present? && return_creation_disposition.present?
        return_items.update_all(disposition: return_creation_disposition.original_code, disposition_id: return_creation_disposition.id)
        render json: {message: "#{return_items.size} item(s) moved to #{params[:disposition]} successfully"}
      else
        render json: {error: "Error in assigning disposition to selected return request(s)"}
      end
    else
      render json: {error: "Please select return request(s) for assigning disposition"}
    end
  end

  def search
    if params[:search].present?
      set_pagination_params(params)
      return_items = ReturnItem.where("return_request_id in (?) or return_sub_request_id in (?)", params[:search].split(","), params[:search].split(",")).page(@current_page).per(@per_page)
      render json: return_items, meta: pagination_meta(return_items)
    else
      render json: {error: "Please enter search term"}
    end
  end

end
