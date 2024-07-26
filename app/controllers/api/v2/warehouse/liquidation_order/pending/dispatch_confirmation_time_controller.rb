class Api::V2::Warehouse::LiquidationOrder::Pending::DispatchConfirmationTimeController < Api::V2::Warehouse::LiquidationOrdersController
  STATUS = "Full Payment Received"

  before_action :check_for_liquidation_order_params, :check_for_dispatch_date_params, only: :update_dispatch_date
  before_action :set_liquidation_orders, only: :update_dispatch_date

  def update_dispatch_date
    begin
      ActiveRecord::Base.transaction do
        @liquidation_orders.each do |liquidation_order|
          dispatch_date_hash = get_dispatch_date_details
          liquidation_order.liquidations.each do |liquidation|
            inventory = liquidation.inventory
            inventory.details.merge!(dispatch_date_hash)
            inventory.save
          end
          liquidation_order.details.merge!(dispatch_date_hash)
          liquidation_order.save
        end
        # TODO :: As of now i don't see any screen that showing dispatch_ready state lots. So to make it visible keeping it in the same bucket.
        # TODO Need to impliment Cron Job to move the lot to dispatch screen on meeting the TAT configuration.
        # status = LookupValue.find_by(code:Rails.application.credentials.lot_status_dispatch_ready)
        # @liquidation_orders.update_all(status: status.original_code, status_id: status.id)
        # create_liquidation_order_histories
      end
      render_success_message("Dispatch date Successfully updated for lot \"#{@liquidation_orders.pluck(:id).join(',')}\"", :ok)
    rescue StandardError => e
      Rails.logger.error(e.message)
      return render_error(e.message.to_s, :unprocessable_entity)
    end
  end

  def get_dispatch_date_details
    account_setting = AccountSetting.first
    tat_date = account_setting&.tat_days.present? ? (params["dispatch_date"].to_date - account_setting.tat_days.days).to_s : params["dispatch_date"]
    {"dispatch_date": params["dispatch_date"], "tat_date": tat_date}
  end
end
