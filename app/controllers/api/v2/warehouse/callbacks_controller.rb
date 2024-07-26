class Api::V2::Warehouse::CallbacksController < ApplicationController
  NO_PAYMENT = 'No Payment'

  skip_before_action :authenticate_user!, :check_permission
  before_action :find_lot, except: [:b2c_product_buyer_details, :extend_b2c_time, :b2c_publish]
  before_action :log_error_from_callback, only: :publish
  before_action :validate_product_buyer_details, only: :b2c_product_buyer_details
  before_action :validate_extend_b2c_time, only: :extend_b2c_time
  before_action :validate_b2c_publish, only: :b2c_publish
  before_action :authenticate_request_token, only: [:b2c_publish, :extend_b2c_time, :b2c_product_buyer_details]

  def publish
    status = LookupValue.find_by(code: Rails.application.credentials.lot_status_in_progress_b2b)
    if @lot.is_moq_lot?
      sub_lot_status = LookupValue.find_by(code: Rails.application.credentials.lot_status_moq_sub_lot_in_progress_b2b)
      @lot.moq_sub_lots.update_all(beam_lot_id: params[:lot_publish_id], lot_request_id: params[:lot_request_id], status: sub_lot_status.original_code, status_id: sub_lot_status.id, republish_status: "success", beam_lot_response: "success")
    end

    @lot.update(
      beam_lot_id: params[:lot_publish_id],
      lot_request_id: params[:lot_request_id],
      status: status.original_code,
      status_id: status.id,
      republish_status: "success",
      beam_lot_response: "success"
    )
    render_success_message("Successfully Updated the Lot on RIMS.", :ok)
  rescue => e
    send_error_back_to_callback_requestor e, 'publish_callback'
  end

  #params:
  #{"bid_details"=>
  #  {
  #    "bid_price"=>"220.0", "bid_status"=>"Participating", "username"=>"gauravpalande", "email"=>nil, 
  #    "mobile"=>"9324432946", "client_ip"=>nil, "is_active"=>"true", "bid_date_time"=>"2023-07-07 07:17:21 UTC", 
  #    "buyer_id"=>"1", "bid_id"=>"37", "full_name"=>"", "shipping_addr1"=>"", "shipping_addr2"=>"", "shipping_addr3"=>"", 
  #    "shipping_city"=>"", "shipping_state"=>"", "shipping_country"=>"", "shipping_pincode"=>""}, "buy_now_price"=>"20000.0", 
  #    "end_date"=>"2023-07-07 07:30:00 UTC", "floor_price"=>"100.0", "increment_slab"=>"20", "lot_name"=>"Lot bacd5a || 3838", 
  #    "lot_number"=>"3838", "lot_publish_id"=>"41", "status"=>"In Progress", "winner_amount_received"=>"0", 
  #    "winner_payment_status"=>"Payment Pending", "winner_price"=>nil, "winner_user"=>"gauravpalande", 
  #    "controller"=>"api/v2/warehouse/callbacks", "action"=>"place_bid"
  #  }
  #}  
  def place_bid
    ActiveRecord::Base.transaction do
      order_status = LookupValue.find_by(original_code: "In Progress B2B")
      update_lot('create_bids', order_status)
      create_bid
    end
    render_success_message("Successfully created bid on RIMS.", :ok)
  rescue => e
    send_error_back_to_callback_requestor e, 'place_bid'
  end

  #params:
  #{"bid_details"=>
  #  {
  #    "bid_price"=>"20000.0", "bid_status"=>"Participating", "username"=>"gauravpalande", "email"=>nil, 
  #    "mobile"=>"9324432946", "client_ip"=>nil, "is_active"=>"true", "bid_date_time"=>"2023-07-07 07:13:00 UTC", 
  #    "buyer_id"=>"1", "bid_id"=>"36", "full_name"=>"", "shipping_addr1"=>"", "shipping_addr2"=>"", "shipping_addr3"=>"", 
  #    "shipping_city"=>"", "shipping_state"=>"", "shipping_country"=>"", "shipping_pincode"=>""}, 
  #    "buy_now_price"=>"20000.0", "end_date"=>"2023-07-07 07:30:00 UTC", "floor_price"=>"2000.0", 
  #    "increment_slab"=>"10", "lot_name"=>"Lot 14f7c2 || 3837", "lot_number"=>"3837", "lot_publish_id"=>"40", 
  #    "status"=>"In Progress", "winner_amount_received"=>"0", "winner_payment_status"=>"Payment Pending", 
  #    "winner_price"=>nil, "winner_user"=>"gauravpalande", "controller"=>"api/v2/warehouse/callbacks", "action"=>"buy_now"
  #  }
  #}  
  def buy_now
    message = ActiveRecord::Base.transaction do
      if @lot.is_moq_lot?
        raise CustomErrors, "Not allow to buy more than \"#{@lot.maximum_lots_per_buyer.to_i}\" lot." if params.dig(:buy_details, :quantity).to_i > @lot.maximum_lots_per_buyer.to_i 
        raise CustomErrors, "Not able to process Available lot quantity is #{@lot.available_sub_lot.count}." if params.dig(:buy_details, :quantity).to_i > @lot.available_sub_lot.count
        @lot.update_moq_lots_status(params)
        "Successfully move #{params.dig(:buy_details, :quantity)} moq sub lots to pending payment for buy_now on RIMS."
      else
        order_status = case params[:winner_payment_status]
        when NO_PAYMENT
          'Confirmation Pending'
        when 'Payment Pending', 'Pending Payment'
          'Pending Payment'
        else
          params[:winner_payment_status]
        end

        order_status = LookupValue.find_by(original_code: order_status)

        create_bid
        update_lot('buy_bids', order_status)
        @lot.end_bid_and_take_decision(end_time: params[:end_date])
        @lot.reload
        @lot.update!(buyer_name: params[:winner_user])
        "Successfully created bid for buy_now on RIMS."
      end
    end
    render_success_message(message, :ok)
  rescue => e
    send_error_back_to_callback_requestor e, 'buy_now'
  end

  # Payload -> { request_id: , external_product_id:, start_time:, end_time: }
  def b2c_publish
    @ecom_liquidation = EcomLiquidation.find_by_external_request_id(params[:request_id])
    @ecom_liquidation.update!(
      external_product_id: params[:external_product_id],
      publish_status: :published,
      status: 'In Progress B2C',
      start_time: params[:start_time].to_datetime,
      end_time: params[:end_time].to_datetime,
      order_number: "OR-EcomLiquidation-#{SecureRandom.hex(6)}"
    )
    @ecom_liquidation.details["published_at"] = format_date(DateTime.now, :p_long)
    @ecom_liquidation.save!
    status = LookupValue.where(original_code: 'In Progress B2C').first
    @ecom_liquidation.liquidation.update!(b2c_publish_status: Liquidation.b2c_publish_statuses["published"], status: status.original_code, status_id: status.id)
    @ecom_liquidation.liquidation.inventory.update_inventory_status!(status)
    @ecom_liquidation.liquidation.create_history(current_user)
    render_success_message("Successfully Updated Ecom Liqudation", :ok)
  end

  def extend_b2c_time
    @ecom_liquidation = EcomLiquidation.find_by_external_product_id(params[:external_product_id])
    @ecom_liquidation.update!(
      start_time: params[:start_time].to_datetime,
      end_time: params[:end_time].to_datetime
    )
    render_success_message("Successfully Updated Ecom Liqudation timings", :ok)
  end

  def b2c_product_buyer_details
    purchase_history_details = params["ecom_purchase_history"]
    @ecom_liquidation = EcomLiquidation.find_by_external_product_id(purchase_history_details["request_id"])
    raise "invalid request_id "if @ecom_liquidation.blank?
    begin
      ActiveRecord::Base.transaction do 
        ecom_purchase_history = @ecom_liquidation.ecom_purchase_histories.new(ecom_purchase_history_params)
        ecom_purchase_history.publish_price = @ecom_liquidation.amount
        ecom_purchase_history.save!
        @ecom_liquidation.quantity -= ecom_purchase_history.quantity
        raise "quantity cannot be negative "if @ecom_liquidation.quantity.negative?
        status = LookupValue.where(original_code: 'Dispatch').first
        @ecom_liquidation.status = 'Dispatch'
        @ecom_liquidation.save!
        liquidation = @ecom_liquidation.liquidation
        liquidation.update!(status: status.original_code, status_id: status.id)
        liquidation.create_history(current_user)
        create_warehouse_order
        create_warehouse_order_items
        render_success_message("Successfully Createad Ecom Purchase History", :ok)
      end
    rescue => exc
      render_error(exc.message, 500)
    end
  end

  def extend_bid
    @lot.update!(end_date: params[:end_date])
    render_success_message("Successfully updated lot end_time on RIMS.", :ok)
  end

  def bid_end
    @lot.end_bid_and_take_decision(end_time: params[:end_date], send_callback: true)
    render_success_message("Successfully ended Bid on RIMS.", :ok)
  end

  private

    def ecom_purchase_history_params
      params.require(:ecom_purchase_history).permit(:status, :order_number, :quantity, :username, :address_1, :address_2, :city, :state, :amount, :delivery_charges, :discount_price)
    end

    def find_lot
      @lot = LiquidationOrder.find_by(id: params[:lot_number])
      render_error("Lot with ID #{params[:lot_number]} could not find on Callback", 422) if @lot.blank?
    end

    def create_warehouse_order
      @warehouse_order_status = LookupValue.find_by_code(Rails.application.credentials.dispatch_status_pending_pickup)
      @liquidation = @ecom_liquidation.liquidation
      @warehouse_order = @ecom_liquidation.build_warehouse_order(
        distribution_center_id: @liquidation.distribution_center_id, 
        vendor_code: @ecom_liquidation.vendor_code,
        vendor_name: @ecom_liquidation.vendor_name,
        reference_number: @ecom_liquidation.order_number,
        client_id: @liquidation.client_id,
        status_id: @warehouse_order_status.id,
        total_quantity: 1
      )
      @warehouse_order.save!
    end
  
    def create_warehouse_order_items
      client_category = ClientSkuMaster.find_by_code(@liquidation.sku_code).client_category rescue nil
      @warehouse_order_item = @warehouse_order.warehouse_order_items.new(
        inventory_id: @liquidation.inventory_id,
        client_category_id: (client_category.id rescue nil),
        client_category_name: (client_category.name rescue nil),
        sku_master_code: @liquidation.sku_code,
        item_description: @liquidation.item_description,
        tag_number: @liquidation.tag_number,
        quantity: 1,
        status_id: @warehouse_order_status.id,
        status: @warehouse_order_status.original_code,
        serial_number: @liquidation.serial_number,
        aisle_location: @liquidation.aisle_location,
        toat_number: @liquidation.toat_number,
        details: @liquidation.inventory.details
      )
      @warehouse_order_item.save!
    end

    def log_error_from_callback
      if params[:error].present?
        params[:error] = params[:error].is_a?(Array) ? params[:error].join(", ") : params[:error]
        Error.create(
          timestamp: Time.now,
          error_type: "LotPublishFailure",
          error_message: params[:error],
          error_code: "LotPublishCallback::Error",
          user: "test",
          request: request.inspect,
          resource_id: @lot.id,
          additional_metadata: "An error occurred while processing Api::V2::Warehouse::CallbacksController#publish_callback"
        )
        @lot.update!(republish_status: 'error', beam_lot_response: params[:error])
        render_success_message("Successfully Logged the Error to the client.", :ok)
      end
    end

    def send_error_back_to_callback_requestor error, method
      Error.create(
        timestamp: Time.now,
        error_type: error.class.to_s,
        error_message: error.message,
        error_code: "LotPublishCallback::Error",
        user: "test",
        request: request.inspect,
        stack_trace: error.backtrace.join("\n"),
        resource_id: @lot.id,
        additional_metadata: "An error occurred while processing Api::V2::Warehouse::CallbacksController##{method}"
      )
      render_error(error.message, 422)
    end

    def update_lot(lot_status, order_status)
      @lot.update!(
        winner_code: params[:winner_user],
        vendor_code: params[:winner_user],
        winner_amount: params[:winner_price],
        payment_status: order_status.original_code,
        amount_received: params[:winner_amount_received],
        end_date: params[:end_date],
        dispatch_ready: false,
        status: order_status.original_code,
        status_id: order_status.id
      )
      @lot.update_liquidation_status(lot_status, current_user)
      LiquidationOrderHistory.create(liquidation_order_id: @lot.id, status: @lot.status, status_id: @lot.status_id)
    end

    def create_bid
      bid_details = params[:bid_details]
      @lot.bids.create!(
        bid_price: bid_details[:bid_price],
        bid_status: bid_details[:bid_status],
        user_name: bid_details[:username],
        user_email: bid_details[:email],
        user_mobile: bid_details[:mobile],
        client_ip: bid_details[:client_ip],
        is_active: bid_details[:is_active],
        created_at: bid_details[:bid_date_time].to_time,
        updated_at: bid_details[:bid_date_time].to_time,
        buyer_id: bid_details[:buyer_id],
        beam_bid_id: bid_details[:bid_id],
        shipping_addr1: bid_details[:shipping_addr1],
        shipping_addr2: bid_details[:shipping_addr2],
        shipping_addr3: bid_details[:shipping_addr3],
        shipping_city: bid_details[:shipping_city],
        shipping_state: bid_details[:shipping_state],
        shipping_country: bid_details[:shipping_country],
        shipping_pincode: bid_details[:shipping_pincode]
      )
    end

    def validate_product_buyer_details
      required_params = {
        request_id: "Missing required param 'request_id'.",
        status: "Missing required param 'status'.",
        order_number: "Missing required param 'order_number'.",
        quantity: "Missing required param 'quantity'.",
        username: "Missing required param 'username'.",
        address_1: "Missing required param 'address_1'.",
        address_2: "Missing required param 'address_2'.",
        city: "Missing required param 'city'.",
        state: "Missing required param 'state'.",
        amount: "Missing required param 'amount'."
      }
      required_params.each do |param, error_message|
        render_error(error_message, 422) and return if params["ecom_purchase_history"][param].blank?
      end
    end

    def validate_b2c_publish
      required_params = {
        request_id: "Missing required param 'request_id'.",
        external_product_id: "Missing required param 'external_product_id'.",
        start_time: "Missing required param 'start_time'.",
        end_time: "Missing required param 'end_time'."
      }
      required_params.each do |param, error_message|
        render_error(error_message, 422) and return if params[param].blank?
      end
    end

    def validate_extend_b2c_time
      required_params = {
        external_product_id: "Missing required param 'external_product_id'.",
        start_time: "Missing required param 'start_time'.",
        end_time: "Missing required param 'end_time'."
      }
      required_params.each do |param, error_message|
        render_error(error_message, 422) and return if params[param].blank?
      end
    end

    def authenticate_request_token
      auth = request.headers["Authorization"]
      decrypted_string = StringEncryptDecryptService.decrypt_string(auth)
      raise 'invalid auth for the request' if decrypted_string != Rails.application.credentials.b2c_publish_key
    end
end
