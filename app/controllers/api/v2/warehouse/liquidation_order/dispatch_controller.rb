class Api::V2::Warehouse::LiquidationOrder::DispatchController < Api::V2::Warehouse::LiquidationOrdersController
  STATUS = "Pending Lot Dispatch"

  private
  def filter_liquidation_order_items
    @liquidation_orders = LiquidationOrder
    dispatch_status = params[:filter]&.delete(:status)
    @liquidation_orders = @liquidation_orders.filter(params[:filter]) if params[:filter].present?
    liquidation_orders_ids = @liquidation_orders.includes(:liquidations).where(liquidations: { distribution_center_id: @distribution_center_ids }, status: self.class::STATUS).pluck(:id)
    if dispatch_status.present?
      status_id = LookupValue.where("original_code in (?)", dispatch_status).pluck(:id)
    else
      status_id = LookupValue.where(code: [Rails.application.credentials.order_status_warehouse_pending_pick, Rails.application.credentials.order_status_warehouse_pending_pack, Rails.application.credentials.order_status_warehouse_pending_dispatch]).pluck(:id)
    end
    @liquidation_orders = LiquidationOrder.joins(:warehouse_orders).where("liquidation_orders.id in (?) AND warehouse_orders.status_id in (?)", liquidation_orders_ids, status_id)
  end
end
