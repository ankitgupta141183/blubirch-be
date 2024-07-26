class Api::V2::Warehouse::LiquidationOrder::Pending::PaymentController < Api::V2::Warehouse::LiquidationOrdersController
  STATUS = ['Pending Payment', 'Partial Payment']

  before_action :check_for_update_params, only: :update
  before_action :set_liquidation_order, only: [:update, :unreserve_sub_lot]

  def update
    ActiveRecord::Base.transaction do
      total_payment_received = @liquidation_order.amount_received.to_i + params[:payment_received].to_i
      return render_error("Amount is greater than pending amount.", 422) if total_payment_received > @liquidation_order.winner_amount.to_i
      payment_status = LookupValue.find_by(code: @liquidation_order.get_payment_status(total_payment_received))
      generate_order_number if payment_status.original_code == "Full Payment Received"
      add_payment_reference_number
      @liquidation_order.update!(amount_received: total_payment_received, status: payment_status.original_code, status_id: payment_status.id, payment_status: payment_status.original_code, payment_status_id: payment_status.id, updated_by_id: current_user.id)
      @liquidation_order.liquidation_order_histories.create!(status: payment_status.original_code, status_id: payment_status.id, details: { user_id: current_user.id, user: current_user.username })
      # Pause the payment sync - if we push to remarketing its getting pushed to dmp also
      # sync_payment_update
      # Uncomment the above code to start payment sync with remarketing
      render_success_message(generate_message(payment_status), :ok)
    end
  rescue Exception => message
    render_error(message.to_s, 500)
  end

  # TODO implimentation CANCEL
  def cancel

  end

  def unreserve_sub_lot
    return render_error("Not a MOQ sub lot", 500) unless @liquidation_order.is_moq_sub_lot?
    ActiveRecord::Base.transaction do
      parent_moq_lot = @liquidation_order.moq_parent_lot
      @ordered_moq_sub_lots = LiquidationOrder.where("moq_order_id = ? AND details ->> 'beam_order_number' = ?", @liquidation_order.moq_order_id, @liquidation_order.details['beam_order_number'])
      raise "Unable to Unreserve sub-lot! Order have Payment initiated." unless @ordered_moq_sub_lots.pluck(:amount_received).compact.sum.zero?
      if parent_moq_lot.present?
        hide_for_pending_decision_status = LookupValue.find_by(code: "lot_status_hide_for_pending_decision")
        if parent_moq_lot.status == hide_for_pending_decision_status.original_code
          pending_decision_status = LookupValue.find_by(code: Rails.application.credentials.lot_status_pending_decision)
          parent_moq_lot.update!(status: pending_decision_status.original_code, status_id: pending_decision_status.id)
        end
        sub_lot_status = LookupValue.find_by(code: Rails.application.credentials.send("lot_status_moq_sub_lot_#{parent_moq_lot.status.parameterize.underscore}"))
        response = sync_unreserve_lot_to_reseller
        if response.code == 200
          Liquidation.where(liquidation_order_id: @ordered_moq_sub_lots.pluck(:id)).update_all(
            liquidation_order_id: @liquidation_order.moq_order_id,
            status: sub_lot_status.original_code,
            status_id: sub_lot_status.id
          )
          @ordered_moq_sub_lots.update_all(
            winner_code: nil,
            vendor_code: nil,
            buyer_name: nil,
            winner_amount: nil,
            amount_received: nil,
            payment_status: nil,
            status: sub_lot_status.original_code,
            status_id: sub_lot_status.id,
            updated_by_id: current_user.id
          )
          parent_moq_lot.update_moq_lot_quantity(@ordered_moq_sub_lots.size)
          lot_history = @ordered_moq_sub_lots.map{|sub_lot| {liquidation_order_id: sub_lot.id, status: sub_lot_status.original_code, status_id: sub_lot_status.id, details: { user_id: current_user.id, user: current_user.username }}}
          LiquidationOrderHistory.create(lot_history)
          render_success_message("Successfully unreserve the lot!", :ok)
        else
          resp_body = JSON.parse(response.body)
          render_error(resp_body['errors'].to_s, 422)
        end
      else
        lot_ids = LiquidationOrder.delete_los(@ordered_moq_sub_lots.pluck(:id), current_user)
        message = generate_delete_lot_message(lot_ids)
        message.gsub!("deleted", "Unreserved")
        render_success_message(message, :ok)
      end
    end
  rescue Exception => message
    render_error(message.to_s, 500)
  end

  private

  def check_for_update_params
    required_params = {
      id: 'Required params "id" is missing!',
      payment_received: 'Required params "payment_received" is missing!',
      transaction_id: 'Required params "transaction_id" is missing!'
    }
    required_params.each do |param, error_message|
      render_error(error_message, 422) and return if params[param].blank?
    end
  end

  def generate_order_number
    @liquidation_order.details["so_number"] = @liquidation_order.order_number
  end

  def sync_payment_update
    url = Rails.application.credentials.reseller_url+"/api/orders/update_payment_details"
    payload = {
      "lot_publish_id": @liquidation_order.beam_lot_id,
      "order_number": @liquidation_order.details['beam_order_number'],
      "payment_amount": params[:payment_received].to_i,
      "transaction_id": params[:transaction_id].to_i,
      "payment_date_time": Time.now
    }
    payload.merge!(sub_lot_id: @liquidation_order.id) if @liquidation_order.is_moq_lot? || @liquidation_order.is_moq_sub_lot?
    sync_data_to_beam(url, payload)
  end

  def sync_unreserve_lot_to_reseller
    url = Rails.application.credentials.reseller_url+"/api/lot_publishes/cancel_reserve_sub_lots_order"
    payload = {
      "order_number": @liquidation_order.details['beam_order_number'],
      "buyer_name": @liquidation_order.buyer_name,
      "sub_lot_ids": @ordered_moq_sub_lots.pluck(:id),
      "id": @liquidation_order.beam_lot_id
    }
    RestClient::Request.execute(method: :post, url: url, payload: payload, verify_ssl: OpenSSL::SSL::VERIFY_NONE)
  rescue => e
    e.response
  end

  def add_payment_reference_number
    @liquidation_order.details["payments"] = [] unless @liquidation_order.details["payments"].present?
    @liquidation_order.details["payments"] << {payment_reference_number: params[:transaction_id], amount: params[:payment_received]}
  end

  def generate_message(payment_status)
    payment_status.original_code == "Full Payment Received" ? "Payment successfully updated for '#{@liquidation_order.id}' & moved to 'Pending Dispatch Confirmation and Time.'" : "Payment successfully updated for '#{@liquidation_order.id}'."
  end
end
