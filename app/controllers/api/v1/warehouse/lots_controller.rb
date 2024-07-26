class Api::V1::Warehouse::LotsController < ApplicationController

  skip_before_action :authenticate_user!
  skip_before_action :check_permission

  def create_bids
    success_lots = []
    error_lots = []
    errors = []
    params[:_json].each do |bid_master|
      begin
        ActiveRecord::Base.transaction do
          liquidation_order = LiquidationOrder.where(lot_name: bid_master[:client_bid_detail][:bid_name]).last
          order_status = LookupValue.where(original_code: bid_master[:client_bid_detail][:status]).last
          if liquidation_order.update(status: bid_master[:client_bid_detail][:status], status_id: order_status.id)
            liquidation_order.liquidations.update_all(status: bid_master[:client_bid_detail][:status], status_id: order_status.id)
            liquidation_order.update_liquidation_status('create_bids', current_user)
            liquidation_order_history = LiquidationOrderHistory.create(liquidation_order_id:liquidation_order.id, status: bid_master[:status], status_id: order_status.id)
          end
          bid_master[:client_bid_detail][:bid_details].each do |bid|
            liquidation_order.bids.create!(bid_price: bid[:bid_price], bid_status: bid[:status], user_name: bid[:username], user_email: bid[:email], user_mobile: bid[:mobile], client_ip: bid[:client_ip], is_active: bid[:is_active], created_at: bid[:bid_time].to_time, updated_at: bid[:bid_time].to_time)
          end
          success_lots << bid_master[:client_bid_detail][:bid_name]
        end
      rescue Exception => message
        error_lots << bid_master[:client_bid_detail][:bid_name]
        errors << message
      end
    end
    render json: { message: "success", status: 200, success_lots: success_lots, error_lots: error_lots, errors: errors }
  end

  def create_paid_bids
    begin
      ActiveRecord::Base.transaction do
        params[:_json].each do |bid_master|
          liquidation_order = LiquidationOrder.where(lot_name: bid_master[:client_bid_detail][:bid_name]).last
          if bid_master[:client_bid_detail][:winner_payment_status] == "No Payment"
            order_status = LookupValue.where(code: Rails.application.credentials.lot_status_confirmation_pending).last
          else
            order_status = LookupValue.where(original_code: bid_master[:client_bid_detail][:winner_payment_status]).last
          end
          liquidation_order.update_attributes(status: order_status.original_code, status_id: order_status.id)
          liquidation_order.update_liquidation_status('create_bids', current_user)
          bid_master[:client_bid_detail][:bid_details].each do |bid|
            liquidation_order.bids.create!(bid_price: bid[:bid_price], bid_status: bid[:status], user_name: bid[:username], user_email: bid[:email], user_mobile: bid[:mobile], client_ip: bid[:client_ip], is_active: bid[:is_active])
          end
          @liquidation_order = liquidation_order
          liquidation_order_history = LiquidationOrderHistory.create(liquidation_order_id:@liquidation_order.id, status: @liquidation_order.status, status_id: @liquidation_order.status_id) 
          @liquidation_order.winner_code = bid_master[:client_bid_detail][:winner_user]
          @liquidation_order.vendor_code = bid_master[:client_bid_detail][:winner_user]
          @liquidation_order.winner_amount = bid_master[:client_bid_detail][:winner_price]
          if bid_master[:client_bid_detail][:winner_payment_status] != "No Payment"
            @liquidation_order.payment_status = order_status.original_code
          end
          @liquidation_order.amount_received = params[:winner_amount_received]
          @liquidation_order.dispatch_ready = false
          @liquidation_order.save
        end
      end # transaction end
      render json: @liquidation_order
    rescue Exception => message
      render json: { errors: message.to_s, status: 500 }
    end # rescue end
  end

end
