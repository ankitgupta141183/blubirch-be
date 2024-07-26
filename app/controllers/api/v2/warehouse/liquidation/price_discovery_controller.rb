class Api::V2::Warehouse::Liquidation::PriceDiscoveryController < Api::V2::Warehouse::LiquidationsController
  STATUS = 'Allocate B2B'

  before_action :set_liquidations, only: [:assign_price]

  def assign_price
    status = LookupValue.find_by(code: params[:liquidation][:price_type])
    message = validate_ewaste_status_for_moq if status.original_code == 'MOQ Price'
    return render_error(message, 422) if message
    message = "#{@liquidations.size} item(s) successfully sent to 'Create Lots (#{status.original_code})'"
    update_liquidations_status(status: status.original_code, status_id: status.id, message: message)
  end
end

