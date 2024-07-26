class Api::V1::Warehouse::ReturnInitiation::ReturnItemsController < ApplicationController

  def index
    set_pagination_params(params)
    return_items = ReturnItem.all.reorder(updated_at: :desc).page(@current_page).per(@per_page)
    render json: return_items, meta: pagination_meta(return_items)
  end

end
