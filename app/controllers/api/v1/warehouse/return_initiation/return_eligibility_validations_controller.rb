class Api::V1::Warehouse::ReturnInitiation::ReturnEligibilityValidationsController < ApplicationController

  def index
    set_pagination_params(params)
    return_creation_pending_eligibility_validation_status = LookupValue.where(code: Rails.application.credentials.return_creation_pending_eligibility_validation_status).first
    return_eligibiltiy_validations = ReturnItem.where(status_id: return_creation_pending_eligibility_validation_status).page(@current_page).per(@per_page)
    render json: return_eligibiltiy_validations, meta: pagination_meta(return_eligibiltiy_validations)
  end

  def approve
    if params[:return_ids].present?
      return_items = ReturnItem.where("id in (?)", params[:return_ids].split(","))
      if return_items.present?
        return_creation_pending_approval_status = LookupValue.where(code: Rails.application.credentials.return_creation_pending_approval_status).first
        return_items.update_all(status: return_creation_pending_approval_status.original_code, status_id: return_creation_pending_approval_status.id)
        render json: {message: "#{return_items.size} item(s) moved to 'Pending Manual Disposition'"}
      else
        render json: {error: "Error in approving return request(s)"}
      end
    else
      render json: {error: "Please select return request(s) for approval"}
    end
  end

  def reject
    if params[:return_ids].present?
      return_items = ReturnItem.where("id in (?)", params[:return_ids].split(","))
      if return_items.present?
        return_creation_closed_reject_status = LookupValue.where(code: Rails.application.credentials.return_creation_closed_reject_status).first
        return_items.update_all(status: return_creation_closed_reject_status.original_code, status_id: return_creation_closed_reject_status.id)
        render json: {message: "#{return_items.size} item(s) moved to Return Claim Requests"}
      else
        render json: {error: "Error in rejecting return request(s)"}
      end
    else
      render json: {error: "Please select return request(s) for rejection"}
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
