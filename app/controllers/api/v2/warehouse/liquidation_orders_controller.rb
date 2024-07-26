class Api::V2::Warehouse::LiquidationOrdersController < ApplicationController
  STATUS = 'Pending Publish'

  before_action -> { set_pagination_params(params) }, only: [:index, :vendor_list, :index_new]
  before_action :get_distribution_centers, only: [:index, :index_new]
  before_action :filter_liquidation_order_items, :search_liquidation_order_items, only: [:index, :index_new]

  def index
    @liquidation_orders = @liquidation_orders.includes(:moq_sub_lot_prices, :warehouse_orders, :quotations, :bids).order('liquidation_orders.updated_at desc').page(@current_page).per(@per_page)
    render_collection(@liquidation_orders, Api::V2::Warehouse::LiquidationOrderSerializer)
  end

  # only used for pending_publish
  def index_new
    @liquidation_orders = @liquidation_orders.order('liquidation_orders.updated_at desc').page(@current_page).per(@per_page)
    render json: @liquidation_orders, each_serializer: Api::V2::Warehouse::LiquidationOrderIndexSerializer, meta: pagination_meta(@liquidation_orders)
    # render_collection(@liquidation_orders, Api::V2::Warehouse::LiquidationOrderSerializer)
  end

  def show
    render_resource(@liquidation_order, Api::V2::Warehouse::LiquidationOrderSerializer)
  end

  def publish
    return render_success_message('Cron is implemented, Lot will be publish via cron job.', :ok)
    success_count = 0
    failed_count = 0
    failed_issues = []
    @liquidation_orders = LiquidationOrder.where(id: params[:id])
    @liquidation_orders.each do |liquidation_order|
      ActiveRecord::Base.transaction do
        response = liquidation_order.publish(current_user)
        api_response = unless response
          success_count += 1
          { republish_status: 'pending', beam_lot_response: nil }
        else
          failed_count += 1
          failed_issues << response
          { republish_status: 'error', beam_lot_response: response }
        end
        liquidation_order.update!(api_response)
      end
    end
    if @liquidation_orders.size == 1
      if failed_issues.present?
        raise failed_issues.join(',')
      else
        render_success_message("#{success_count} Lot(s) successfully published & moved to ‘In Progress B2B’.", :ok)
      end
    else
      render_success_message("#{success_count} Lot(s) successfully published & moved to ‘In Progress B2B’.", :ok)
    end
  rescue Exception => message
    render_error(message.to_s, 500)
  end

  def update
    ActiveRecord::Base.transaction do
      if @liquidation_order.is_moq_lot?
        liquidation_status = LookupValue.find_by(code: Rails.application.credentials.liquidation_status_moq_price)
        @liquidation_order.moq_sub_lots.each do |moq_sub_lot|
          moq_sub_lot.delete_lot(liquidation_status, current_user)
        end
        @liquidation_order.moq_sub_lot_prices.delete_all
        @liquidation_order.reload
        @moq_lot_params[:lot].merge!({ republish_status: nil, beam_lot_response: nil })
        @liquidation_order.update!(@moq_lot_params[:lot])
        @liquidation_order.create_sub_lots_and_prices(@moq_lot_params, current_user)
        updated_lot = @liquidation_order
      else
        updated_lot = @liquidation_order.update_lot(formatted_lot_params, current_user)
        validate_update_lot
      end
      render_success_message("Lot details successfully added for #{ updated_lot.id }", :ok)
    end
  rescue Exception => message
    render_error(message.to_s, 500)
  end

  def lot_images
    lot_images = @liquidation_order.lot_image_urls.uniq
    all_images = @liquidation_order.inventory_grading_details.group_by{|a| a.inventory_id}.map do |inventory_grading_detail|
      inventory_grading_detail.last.last.details["final_grading_result"]["Item Condition"][0]["annotations"].last["src"] rescue ''
    end.reject(&:empty?)
    inv_images = (all_images - lot_images).flatten.compact.uniq
    render json: { lot_images: format_links(lot_images), inv_images: format_links(inv_images) }
  end

  private

    def remove_lots
      begin
        lot_ids = LiquidationOrder.delete_los(params[:liquidation_order][:ids], current_user)
        message = generate_delete_lot_message(lot_ids)
        render_success_message(message, :ok)
      rescue StandardError => e
        Rails.logger.error(e.message)
        return render_error(e.message.to_s, :unprocessable_entity)
      end
    end

    def generate_delete_lot_message(lot_ids, message = "")
      message += "Successfully deleted! Lots #{lot_ids[:successfull_deleted_ids].size} are deleted. " if lot_ids[:successfull_deleted_ids].present?
      message += "Unable to delete lots! #{lot_ids[:bids_present_ids].size} have Bids present, " if lot_ids[:bids_present_ids].present?
      message += "Unable to delete lots! #{lot_ids[:amount_received_ids].size} have Payment initiated." if lot_ids[:amount_received_ids].present?
      message
    end

    def search_liquidation_order_items
      @liquidation_orders = @liquidation_orders.search_by_text(params[:search_text]) if params[:search_text].present?
    end

    def filter_liquidation_order_items
      @liquidation_orders = LiquidationOrder
      params.dig(:filter, :price_discovery_method).push("MOQ Sub Lot") if params.dig(:filter, :price_discovery_method)&.include?('MOQ Lot')
      @liquidation_orders = @liquidation_orders.filter(params[:filter]) if params[:filter].present?
      @liquidation_orders = @liquidation_orders.where(distribution_center_id: @distribution_center_ids, status: self.class::STATUS)
    end

    def set_liquidation_order
      @liquidation_order = LiquidationOrder.find_by(id: params[:id])
      render_error("Could not find Lot with ID :: #{params[:id]}", 422) if @liquidation_order.blank?
    end

    def set_liquidation_orders
      @liquidation_orders = LiquidationOrder.where(id: params[:liquidation_order][:ids])
    end

    def check_for_liquidation_order_params
      return render_error('Required params liquidation_order_ids is missing!', :unprocessable_entity) if params.dig(:liquidation_order, :ids).blank?
    end

    def update_bid_timing
      begin
        ActiveRecord::Base.transaction do
          update_bid_timing_for_lots
          update_bid_timing_for_moq_sub_lots
        end
        render_success_message("Successfully updated!", :ok)
      rescue StandardError => e
        Rails.logger.error(e.message)
        return render_error('Something went wrong.', :unprocessable_entity)
      end
    end

    def update_bid_timing_for_lots
      @liquidation_orders.update(liquidation_order_date_params.as_json)
      create_liquidation_order_histories(liquidation_order_date_params.as_json)
    end

    def update_bid_timing_for_moq_sub_lots
      moq_parent_lots = @liquidation_orders.select{|lot| lot.is_moq_lot?}

      LiquidationOrder.where(moq_order_id: moq_parent_lots.pluck(:id)).update_all(liquidation_order_date_params.as_json)
    end

    def liquidation_order_date_params
      params.require(:liquidation_order).permit(:start_date, :end_date)
    end

    def create_liquidation_order_histories(details={})
      history_records = @liquidation_orders.map do |lo|
        { liquidation_order_id: lo.id, status_id: lo.status_id, status: lo.status, details: details.merge({ user_id: current_user.id, user: current_user.username })}
      end
      LiquidationOrderHistory.create(history_records)
    end

    def check_for_dispatch_date_params
      if params['dispatch_date'].present?
        Date.parse(params['dispatch_date'])
      else
        return render_error('Required dispatch_date is missing!', :unprocessable_entity)
      end
    end

    def lot_params
      params.require(:lot).permit(:lot_name, :lot_desc, :mrp, :end_date, :start_date, :order_amount, :quantity, :floor_price, :reserve_price, :buy_now_price, :increment_slab, :lot_image_urls, :delivery_timeline, :additional_info, :images, :image_urls, :bid_value_multiple_of, approved_buyer_ids: [], liquidations: [ :reason, :new_lot_name, :remark, tag_numbers: [] ] )
    end

    def format_links links
      links.map{ |link| { file_name: File.basename(link), url: link } }.compact
    end

    def sync_data_to_beam url, payload
      RestClient::Request.execute(method: :patch, url: url, payload: payload, verify_ssl: OpenSSL::SSL::VERIFY_NONE)
    rescue => exception
      response = exception.response
      Rails.logger.info(response.body)
    end

    def validate_update_lot
      return if @liquidation_order.is_moq_lot?

      unless mrp_greater_than_other_prices?
        raise CustomErrors.new "MRP should be more than all other prices."
      end

      unless validate_buy_now_price
        raise CustomErrors.new "BuyNowPrice should be more (reverse and floor price) and it should be less than mrp."
      end
    end

    def mrp_greater_than_other_prices?
      mrp = @liquidation_order.mrp
      mrp >= @liquidation_order.buy_now_price &&
      mrp >= @liquidation_order.reserve_price &&
      mrp >= @liquidation_order.floor_price
    end

    def validate_buy_now_price
      buy_now_price = @liquidation_order.buy_now_price
      buy_now_price <= @liquidation_order.mrp &&
      buy_now_price >= @liquidation_order.reserve_price &&
      buy_now_price >= @liquidation_order.floor_price
    end

    def formatted_lot_params
      liquidation_ids = params[:liquidation_ids]
      details = @liquidation_order.details || {}
      details['approved_buyer_ids'] = params[:approved_buyer_ids]
      {
        lot: {
          lot_name: params[:lot_name],
          lot_desc: params[:lot_desc],
          mrp: params[:lot_mrp],
          end_date: params[:end_date],
          start_date: params[:start_date],
          order_amount: params[:lot_expected_price],
          quantity: liquidation_ids&.count,
          floor_price: params[:floor_price]&.to_f,
          reserve_price: params[:reserve_price]&.to_f,
          buy_now_price: params[:buy_now_price]&.to_f,
          increment_slab: params[:increment_slab]&.to_i,
          delivery_timeline: params[:delivery_timeline],
          additional_info: params[:additional_info],
          bid_value_multiple_of: params[:bid_value_multiple_of],
          details: details,
        },
        images: params[:images],
        removed_urls: params[:removed_urls],
        image_urls: params[:image_urls],
        liquidation_ids: liquidation_ids,
      }
    end
end
