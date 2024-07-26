class Api::V2::Warehouse::LiquidationOrder::B2b::InProgressController < Api::V2::Warehouse::LiquidationOrdersController
  STATUS = "In Progress B2B"

  before_action :check_for_liquidation_order_params, only: [:update_timing, :delete_lots]
  before_action :check_for_liquidation_order_reserve_params, only: :reserve
  before_action :set_liquidation_orders, only: [:update_timing, :reserve, :delete_lots]
  before_action :search_vendor_masters, only: :vendor_list
  before_action :set_liquidation_order, only: [:show, :update]

  def update_timing
    update_bid_timing
  end

  def delete_lots
    remove_lots
  rescue StandardError => e
    Rails.logger.error(e.message)
    return render_error(e.message, :unprocessable_entity)
  end

  def reserve
    begin
      ActiveRecord::Base.transaction do
        buyer = BuyerMaster.find_by(username: liquidation_order_reserve_params['winner_code'])
        pending_payment_status = LookupValue.find_by(code: Rails.application.credentials.lot_status_pending_payment)
        @liquidation_orders.each do |liquidation_order|
          if liquidation_order.is_moq_lot?
            liquidation_order.moq_sub_lots.update_all(winner_code: buyer.username, buyer_name: buyer.full_name, winner_amount: liquidation_order.buy_now_price, status: pending_payment_status.original_code, status_id: pending_payment_status.id, updated_by_id: current_user.id)
          end
          liquidation_order.update(winner_code: buyer.username, buyer_name: buyer.full_name, winner_amount: liquidation_order.buy_now_price, status: pending_payment_status.original_code, status_id: pending_payment_status.id, updated_by_id: current_user.id)
          sync_reserve_lot(liquidation_order)
        end
        create_liquidation_order_histories(liquidation_order_reserve_params.as_json)
      end
      render_success_message("Lot \"#{@liquidation_orders.pluck(:id).join(',')}\" successfully reserved to \"#{buyer.full_name}\" & moved to ‘Pending Payment’ page", :ok)
    rescue StandardError => e
      Rails.logger.error(e.message)
      return render_error('Something went wrong.', :unprocessable_entity)
    end
  end

  def vendor_list
    @buyers = @buyers.order(:username).page(@current_page).per(@per_page)
    render_collection(@buyers, Api::V2::BuyerMasterSerializer)
  end

  private

  def search_vendor_masters
    @buyers = BuyerMaster
    @buyers = @buyers.search_by_text(params[:search_text]) if params[:search_text].present?
  end

  def check_for_liquidation_order_reserve_params
    return render_error('Required params liquidation_order is missing!', :unprocessable_entity) if params[:liquidation_order].blank?
    return render_error('Required params liquidation_order_winner_code is missing!', :unprocessable_entity) if params[:liquidation_order][:winner_code].blank?
  end

  def liquidation_order_reserve_params
    params.require(:liquidation_order).permit(:winner_code)
  end

  def sync_reserve_lot(liquidation_order)
    if liquidation_order.beam_lot_id.present?
      url = Rails.application.credentials.reseller_url+"/api/bids/reserve"
      payload = {
        lot_publish_id: liquidation_order.beam_lot_id,
        username: liquidation_order.winner_code
      }
      RestClient::Request.execute(method: :post, url: url, payload: payload, verify_ssl: OpenSSL::SSL::VERIFY_NONE)
    end
  end
end
