class Api::V2::Warehouse::VendorReturn::DispatchController < Api::V2::Warehouse::VendorReturnsController
  STATUS = 'Pending Settlement'

  skip_before_action :filter_vendor_return_items, :search_vendor_return_items, only: :index
  before_action :get_dispatch_items, :dispatch_item_filters, only: :index

  def index
    if @warehouse_order_items.present?
      @warehouse_order_items = @warehouse_order_items.page(@current_page).per(@per_page)
      render json: @warehouse_order_items, each_serializer: Api::V2::Warehouse::VendorReturnWarehouseOrderItemSerializer, meta: pagination_meta(@warehouse_order_items) 
    else
      render json: {markdowns: @warehouse_order_items, meta: pagination_meta(@warehouse_order_items) }
    end
  end

  private

  def get_dispatch_items
    set_pagination_params(params)
    @warehouse_order_items = WarehouseOrderItem.joins(:warehouse_order).includes(:inventory, :warehouse_order).where("tab_status in (?) AND warehouse_orders.orderable_type = 'VendorReturnOrder' AND warehouse_orders.distribution_center_id IN (?)", [ 1, 2, 3 ], @distribution_center_ids)&.order("warehouse_order_items.updated_at desc")
  end

  def dispatch_item_filters
    @warehouse_order_items = @warehouse_order_items.where(tag_number: params[:search_text].split(',').collect(&:strip).flatten) if params[:search_text].present?
  end
end
