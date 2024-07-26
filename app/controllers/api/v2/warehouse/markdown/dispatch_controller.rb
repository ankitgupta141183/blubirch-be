class Api::V2::Warehouse::Markdown::DispatchController < Api::V2::Warehouse::MarkdownsController
  STATUS = 'Pending Transfer Out Dispatch'

  skip_before_action :filter_markdown_items, :search_markdown_items, only: :index
  before_action :get_dispatch_items, :dispatch_item_filters, only: :index

  def index
    if @warehouse_order_items.present?
      @warehouse_order_items = @warehouse_order_items.page(@current_page).per(@per_page)
      render json: @warehouse_order_items, each_serializer: Api::V2::Warehouse::MarkdownWarehouseOrderItemSerializer, meta: pagination_meta(@warehouse_order_items) 
    else
      render json: {markdowns: @warehouse_order_items, meta: pagination_meta(@warehouse_order_items) }
    end
  end

  private

  def get_dispatch_items
    set_pagination_params(params)
    warehouse_orders = WarehouseOrder.select(:id).where(orderable_type: "MarkdownOrder")
    return @warehouse_order_items if warehouse_orders.blank?
    if warehouse_orders.present?
      @warehouse_order_items = WarehouseOrderItem.where(warehouse_order_id: warehouse_orders.pluck(:id)).where("tab_status in (?)", [ 1, 2, 3 ])&.order("updated_at desc")
    end
  end

  def dispatch_item_filters
    @warehouse_order_items = @warehouse_order_items.where(tag_number: params[:search_text].split(',').collect(&:strip).flatten) if params[:search_text].present?
  end
end
