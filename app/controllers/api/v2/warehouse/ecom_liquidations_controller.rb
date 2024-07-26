class Api::V2::Warehouse::EcomLiquidationsController < ApplicationController
  before_action -> { set_pagination_params(params) }, only: [:dispatch_orders]
  before_action :filter_liquidation_order_items, :filter_data, only: :dispatch_orders

  def dispatch_orders
    @ecom_liquidations = @ecom_liquidations.order('ecom_liquidations.updated_at desc').page(@current_page).per(@per_page)
    render_collection(@ecom_liquidations, Api::V2::Warehouse::EcomLiquidationDispatchSerializer)
  end

  def filter_data
    @ecom_liquidations = @ecom_liquidations.joins(:ecom_purchase_histories).where("ecom_purchase_histories.username IN (?)", params['buyer_name'].split_with_gsub) if params['buyer_name'].present?
    @ecom_liquidations = @ecom_liquidations.joins(warehouse_order: :warehouse_order_items).where("warehouse_order_items.status =  ?", params['status']) if params['status'].present?
    @ecom_liquidations = @ecom_liquidations.where("inventory_sku IN (?)", params['article_id'].split_with_gsub) if params['article_id'].present?
  end

  def filter_liquidation_order_items
    @ecom_liquidations = EcomLiquidation.where(status: "Dispatch")
    @distribution_center_ids = @distribution_center.present? ? [@distribution_center.id] : current_user.distribution_centers.pluck(:id)
    @ecom_liquidations = @ecom_liquidations.joins(:liquidation).where("liquidations.distribution_center_id IN (#{ @distribution_center_ids.join(",")})")
  end
end
