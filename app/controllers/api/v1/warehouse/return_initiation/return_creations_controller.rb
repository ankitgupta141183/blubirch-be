class Api::V1::Warehouse::ReturnInitiation::ReturnCreationsController < ApplicationController

  skip_before_action :check_permission, only: [:create_return_items]
  skip_before_action :authenticate_user!, only: [:create_return_items]

 	def index

  end

  def create
    params.permit!
    return_item, errors = ReturnItem.create_line_items(params[:return_item], current_user)
    if return_item
      render json: {message: "Return Items got created successfully"}
    else
      render json: {error: errors.join(", ")}
    end
  end

  def create_return_items
    params.permit!
    return_creation_item = ReturnCreationItem.create(payload: params[:return_items], batch_number: params[:batch_number], status: "Initiated")
    if return_creation_item.save
      render json: {message: "Return Items got created successfully"}, status: 200
    else
      render json: {message: "Error increating return items"}, status: :unprocessable_entity
    end
  end

  def search
    if params[:search_type].present?
      query = []
      if params[:search_type][:return_request_id].present?
        query << "lower(return_request_id) ilike '%#{params[:search_type][:return_request_id].downcase}%'"
      end
      if params[:search_type][:return_sub_request_id].present?
        query << "lower(return_sub_request_id) ilike '%#{params[:search_type][:return_sub_request_id].downcase}%'"
      end
      if params[:search_type][:return_type].present?
        query << "lower(return_type) ilike '%#{params[:search_type][:return_type].downcase}%'"
      end
      if params[:search_type][:status].present?
        query << "lower(status) ilike '%#{params[:search_type][:status].downcase}%'"
      end
      return_items = ReturnItem.where(query.join(" and ")).reorder(updated_at: :desc).page(@current_page).per(@per_page)
      render json: return_items, meta: pagination_meta(return_items)
    else
      render json: {error: "Please enter some search term"}
    end
  end

  def delete_return_items
    return_items = ReturnItem.where("id in (?)", params[:return_item_ids])
    if return_items.present?
      if ReturnItem.update_quantity_information(return_items)
        render json: {message: "#{return_items.size} Return Sub Request(s) deleted successfully"}
      else
        render json: {error: "Error in deleting return items"}
      end
    else
      render json: {error: "Please select some return sub request(s) to delete"}
    end
  end

end
