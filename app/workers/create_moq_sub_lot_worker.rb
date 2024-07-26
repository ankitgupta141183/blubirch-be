class CreateMoqSubLotWorker
  include Sidekiq::Worker

  def perform(parent_lot_id, moq_lot_params, current_user_id)
    lot_status = LookupValue.find_by(code: Rails.application.credentials.lot_status_ready_for_publishing)
    parent_lot = LiquidationOrder.find_by_id(parent_lot_id)
    parent_lot.update(details: parent_lot.details.merge({'sub_lot_creation': 'started'}))
    current_user = User.find_by(id: current_user_id)
    moq_lot_params = JSON.parse(moq_lot_params)
    parent_lot.create_sub_lots_and_prices(moq_lot_params, current_user)
    parent_lot.update(status: lot_status.original_code, status_id: lot_status.id, details: parent_lot.details.merge({'sub_lot_creation': 'completed'}))
  end
end