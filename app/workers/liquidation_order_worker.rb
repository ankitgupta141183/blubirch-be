class LiquidationOrderWorker
  include Sidekiq::Worker

  def perform(options)
    options = options.with_indifferent_access
    user = User.find_by_id(options['user_id'])
    liquidation_status = LookupValue.find_by(id: options['liquidation_status_id'])
    if options['sub_lot_ids'].present?
      LiquidationOrder.where(id: options['sub_lot_ids']).each do |lot|
        liquidations = lot.liquidations
        remove_and_create_history(liquidations, user, liquidation_status, lot.id)
        lot.destroy
      end
    else
      liquidations = Liquidation.where(id: options['liquidation_ids'])
      remove_and_create_history(liquidations, user, liquidation_status, options['liquidation_order_id'])
    end
  end

  def remove_and_create_history(liquidations, user, liquidation_status, liquidation_order_id)
    liquidations.map { |liquidation| liquidation.release_from_current_lot(user, liquidation_status)}
    LiquidationOrderHistory.create(liquidation_order_id: liquidation_order_id, status: liquidation_status.original_code, created_at: Time.now, updated_at: Time.now, details: { deleted_by_user_id: user&.id, deleted_by_user_name: user&.full_name })
  end
end