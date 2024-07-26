class Api::V2::Warehouse::VendorReturnsController < ApplicationController
  before_action -> { set_pagination_params(params) }, only: :index
  before_action :get_distribution_centers, only: [:index, :brand_list, :vendor_list]
  before_action :filter_vendor_return_items, :search_vendor_return_items, only: [:index, :brand_list, :vendor_list]

  def index
    @vendor_returns = @vendor_returns.order('created_at desc').page(@current_page).per(@per_page)
    render_collection(@vendor_returns, Api::V2::Warehouse::VendorReturnSerializer)
  end

  private

  def filter_vendor_return_items
    @vendor_returns = VendorReturn
    @vendor_returns = @vendor_returns.filter(params[:filter]) if params[:filter].present?
    @vendor_returns = @vendor_returns.where(distribution_center_id: @distribution_center_ids, is_active: true, status: self.class::STATUS)
  end

  def search_vendor_return_items
    @vendor_returns = @vendor_returns.search_by_text(params[:search_text].split(',').map(&:strip).join(', ')) if params[:search_text].present?
  end

  def set_vendor_returns
    @vendor_returns = VendorReturn.where(id: params[:vendor_return][:ids])
  end
end
