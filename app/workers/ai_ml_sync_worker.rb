class AiMlSyncWorker
  include Sidekiq::Worker

  def perform(liquidation_order_id)
    liquidation_order = LiquidationOrder.find_by_id(liquidation_order_id)
    AiPricingService.new(liquidation_order).call if liquidation_order.present?
  end
end