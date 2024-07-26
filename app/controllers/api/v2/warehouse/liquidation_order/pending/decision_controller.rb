class Api::V2::Warehouse::LiquidationOrder::Pending::DecisionController < Api::V2::Warehouse::LiquidationOrdersController
  STATUS = 'Pending Decision'

  skip_before_action :authenticate_user!, :check_permission, only: :republish_callback
  before_action :set_liquidation_order, only: [:get_bidders, :republish, :republish_callback]
  before_action :check_for_update_params, only: :update
  before_action :check_if_republish_already_in_progress, only: :republish
  before_action :set_lot_attachments, :clean_and_abort_the_republish_if_service_responded_with_error, only: :republish_callback
  before_action :check_for_republish_errors, only: [:republish, :republish_callback]
  before_action :check_for_liquidation_order_params, only: :delete_lots
  before_action :set_liquidation_orders, only: :delete_lots
  before_action :check_if_breaked_lot, only: [:republish], if: -> { @liquidation_order.is_moq_lot? }


  def update
    ActiveRecord::Base.transaction do
      @liquidation_order = LiquidationOrder.includes(:liquidations).find_by(id: params[:id])
      if @liquidation_order.status == 'Partial Payment'
        message = "Lot '#{@liquidation_order.id}' is in 'Partial Payment' status & already assigned to '#{@liquidation_order.buyer_name}', can not assign new buyer."
      else
        # pending_approval_status = LookupValue.find_by(code: Rails.application.credentials.liquidation_status_pending_approval)
        # @liquidation_order.details["old_buyer_details"] = { winner_code: @liquidation_order.winner_code, buyer_name: @liquidation_order.buyer_name, winner_amount: @liquidation_order.winner_amount, old_status_id: @liquidation_order.status_id, old_status: @liquidation_order.status }
        # @liquidation_order.update(status: pending_approval_status.original_code, status_id: pending_approval_status.id, winner_code: params[:vendor_code], buyer_name: params[:user_name], winner_amount: params[:higest_bid], updated_by_id: current_user.id)
        # @liquidation_order.liquidation_order_histories.create(status: pending_approval_status.original_code, status_id: pending_approval_status.id, details: { user_id: current_user.id, user: current_user.username })
        # send_approval_request
        # message = "Lot '#{@liquidation_order.id}' assigned to '#{params[:user_name]}' & moved to 'Pending Approvals' page for Business Head's approval."

        # DEM-167 Below code should be removed if uncommenting above code.
        # Skipping approval request as per discussion with product team.

        @liquidation_order.details["old_buyer_details"] = { winner_code: @liquidation_order.winner_code, buyer_name: @liquidation_order.buyer_name, winner_amount: @liquidation_order.winner_amount, old_status_id: @liquidation_order.status_id, old_status: @liquidation_order.status }
        @liquidation_order.assign_attributes(winner_code: params[:vendor_code], buyer_name: params[:user_name], winner_amount: params[:higest_bid], updated_by_id: current_user.id)
        @liquidation_order.approve_winner_details
        message = "Lot '#{@liquidation_order.id}' assigned to '#{params[:user_name]}' & moved to 'Pending Payment'."
      end
      render_success_message(message, :ok)
    end
  rescue Exception => message
    render_error(message.to_s, 500)
  end

  def delete_lots
    remove_lots
  end

  def republish
    ActiveRecord::Base.transaction do
      if @liquidation_order.status == 'Partial Payment'
        return render_success_message("Lot '#{@liquidation_order.id}' is in 'Partial Payment' status & already assigned to '#{@liquidation_order.buyer_name}', can not publish again.", :ok)
      else
        @liquidation_order.update!(republish_status: 'pending')
        RepublishWorker.new.perform(lot_params)
        return render_success_message("Lot ID '#{@liquidation_order.id}' successfully republished & moved to 'In Progress B2B' page.", :ok)
      end
    end
  rescue Exception => message
    render_error(message.to_s, 500) and return
  end

  def get_bidders
    bid_detail = get_bidder_details(@liquidation_order)
    render json: {bids_details: bid_detail}, status: 200
  end

  def republish_callback
    ActiveRecord::Base.transaction do
      lot_type = LookupValue.find_by(code: Rails.application.credentials.liquidation_lot_type_beam_lot)
      lot_status = LookupValue.find_by(code: Rails.application.credentials.lot_status_in_progress)
      new_liquidation_status = LookupValue.where(code: Rails.application.credentials.liquidation_pending_lot_dispatch_status).first
      archived_status = LookupValue.find_by(code: Rails.application.credentials.lot_status_archived)
      @liquidation_order.update(status: archived_status.original_code, status_id: archived_status.id)
      liquidation_items = @liquidation_order.liquidations
      liquidation_order_new = LiquidationOrder.create!({
        lot_name: lot_params[:lot_name],
        lot_desc: lot_params[:lot_desc],
        mrp: lot_params[:lot_mrp],
        end_date: lot_params[:end_date],
        start_date: lot_params[:start_date],
        status: lot_status.original_code,
        status_id: lot_status.id,
        order_amount: lot_params[:lot_expected_price],
        quantity:liquidation_items.count,
        lot_type: lot_type.original_code,
        lot_type_id: lot_type.id,
        floor_price: lot_params[:floor_price].to_f,
        reserve_price: lot_params[:reserve_price].to_f,
        buy_now_price: lot_params[:buy_now_price].to_f,
        increment_slab: lot_params[:increment_slab].to_i,
        lot_image_urls: (JSON.parse(lot_params[:images]) rescue nil),
        beam_lot_id: lot_params[:new_bid_master_id]
      })

      if @lot_attachments.present?
        liquidation_order_new.lot_attachments << @lot_attachments
        lot_images = (liquidation_order_new.lot_image_urls += @lot_attachments.map(&:attachment_file_url)).flatten.compact.uniq
        liquidation_order_new.update(lot_image_urls: lot_images)
      end
      LiquidationOrderHistory.create(liquidation_order_id: liquidation_order_new.id, status: lot_status.original_code, status_id: lot_status.id)
      @liquidation_order.update_liquidation_status('update_lot_beam_status', nil, liquidation_order_new.id, { lot_name: lot_params[:lot_name], lot_type: lot_type.original_code, lot_type_id: lot_type.id })
      @liquidation_order.update(republish_status: 'success')
      render_success_message('Successfully Republished on BEAM', :ok)
    end
  rescue Exception => message
    handle_error(message)
  end

  private

  def send_approval_request
    details = { 
      tag_number: @liquidation_order.liquidations.pluck(:tag_number).compact.join(', '),
      article_number: @liquidation_order.liquidations.pluck(:sku_code).compact.join(', '),
      beam_lot_id: @liquidation_order.beam_lot_id,
      mrp: @liquidation_order.mrp,
      requested_by: current_user.full_name,
      start_date: CommonUtils.format_date(@liquidation_order.start_date_with_localtime.to_date),
      end_date: CommonUtils.format_date(@liquidation_order.end_date_with_localtime.to_date),
      requested_date: CommonUtils.format_date(Date.current.to_date),
      subject: "Approval required for Pending Decision of #{@liquidation_order.beam_lot_id}",
      rims_url: get_host,
      rule_engine_type: get_rule_engine_type
    }
    ApprovalRequest.create_approval_request(object: @liquidation_order, request_type: 'liquidation_payment_approval', request_amount: params["higest_bid"], details: details)
  end

  def check_for_update_params
    render_error('Required params "id" is missing!', :unprocessable_entity) and return if params[:id].blank?
    render_error('user name and vendor_code params are missing', :unprocessable_entity) and return if params[:user_name].blank? && params[:vendor_code].blank?
    render_error('Required params "higest_bid" is missing!', :unprocessable_entity) and return if params[:higest_bid].blank?
  end

  def get_bidder_details(liquidation_order)
    bidder_array = []
    if ['Beam Lot', 'Competitive Lot'].include?(liquidation_order.lot_type)
      liquidation_order.bids.group_by(&:user_name).each do |user_name, bids|
        higest_bid = bids.max_by{ |bid| bid.bid_price }
        bidder_array << { higest_bid_id: higest_bid.id, user_name: higest_bid.user_name, user_email: higest_bid.user_email, organization: nil, higest_bid: higest_bid.bid_price }
      end
    elsif liquidation_order.lot_type == 'Email Lot'
      Quotation.includes(:vendor_master).where(liquidation_order_id: liquidation_order.id).group_by(&:vendor_master).each do |vendor, bids|
        higest_bid = bids.max_by{ |bid| bid.expected_price }
        bidder_array << { higest_quotation_id: higest_bid.id, vendor_code: vendor.vendor_code, user_name: vendor.vendor_name, user_email: vendor.vendor_email, organization: nil, higest_bid: higest_bid.expected_price }
      end
    end
    bidder_array
  end

  def set_lot_attachments
    @lot_attachments = LotAttachment.where(id: params[:lot_attachment_ids])
  end

  def lot_params
    return moq_lot_params if @liquidation_order.is_moq_lot?
    {
      id: params[:id],
      lot_name: params[:lot_name],
      lot_desc: params[:lot_desc],
      lot_mrp: params[:lot_mrp],
      end_date: params[:end_date],
      start_date: params[:start_date],
      lot_expected_price: params[:lot_expected_price],
      floor_price: params[:floor_price]&.to_f,
      reserve_price: params[:reserve_price]&.to_f,
      buy_now_price: params[:buy_now_price]&.to_f,
      increment_slab: params[:increment_slab]&.to_i,
      delivery_timeline: params[:delivery_timeline],
      additional_info: params[:additional_info],
      bid_value_multiple_of: params[:bid_value_multiple_of],
      images: params[:images],
      new_bid_master_id: params[:new_bid_master_id],
      message: params[:message],
      status: params[:status],
      lot_attachment_ids: params[:lot_attachment_ids],
      error_message: params[:error_message],
      image_urls: params[:image_urls],
      bidding_method: current_user.bidding_method,
      approved_buyer_ids: params[:approved_buyer_ids],
      current_user: current_user
    }
  end

  def check_for_republish_errors
    permit_lot_params = %i[lot_name start_date end_date]
    permit_lot_params += if @liquidation_order.is_moq_lot?
      [:id, :lot_desc, :delivery_timeline, :maximum_lots_per_buyer, {lot_range: [:from_lot, :to_lot, :price_per_lot]}]
    else
      %i[floor_price reserve_price buy_now_price increment_slab bid_value_multiple_of]
    end
    errors = []

    permit_lot_params.each do |param|
      if param.is_a?(Hash)
        param.each do |key, value|
          value.each do |val|
            lot_params[key].each do |v|
              errors << "#{v.to_s.titleize} can not be blank." if v[val].blank?
            end
          end
        end
      else
        errors << "#{param.to_s.titleize} can not be blank." if lot_params.dig(:lot, param).blank? && lot_params[param].blank?
      end
    end

    return render_error(errors, 500) if errors.present?
  end

  def check_if_republish_already_in_progress
    return render_error("Liquidation order with given Id #{params[:id]} is already queued for republish.", 422) if @liquidation_order.republish_pending?
  end

  def clean_and_abort_the_republish_if_service_responded_with_error
    return if lot_params[:status] == "200"
    handle_error(lot_params[:error_message])
  end

  def handle_error(message)
    @lot_attachments.destroy_all if @lot_attachments.present?
    @liquidation_order.update(republish_status: 'error')
    return render_error(message, 500)
  end

  def moq_lot_params
    lot_type = LookupValue.find_by(code: Rails.application.credentials.liquidation_lot_type_moq_lot)
    lot_status = LookupValue.find_by(code: Rails.application.credentials.lot_status_ready_for_republishing)
    sub_lot_type = LookupValue.find_by(code: Rails.application.credentials.liquidation_lot_type_moq_sub_lot)
    sub_lot_status = LookupValue.find_by(code: Rails.application.credentials.lot_status_ready_for_publishing_sub_lot)
    details = @liquidation_order.details.merge({'approved_buyer_ids' => params[:approved_buyer_ids]})
    {
      lot: {
        lot_name: params[:lot_name],
        lot_desc: params[:lot_desc],
        end_date: params[:end_date],
        start_date: params[:start_date],
        status:lot_status.original_code,
        status_id: lot_status.id,
        lot_type: lot_type.original_code,
        lot_type_id: lot_type.id,
        delivery_timeline: params[:delivery_timeline],
        maximum_lots_per_buyer: params[:maximum_lots_per_buyer],
        details: details
      },
      id: params[:id],
      lot_range: params[:lot_range],
      sub_lot_status: sub_lot_status.original_code,
      sub_lot_status_id: sub_lot_status.id,
      sub_lot_type: sub_lot_type.original_code,
      sub_lot_type_id: sub_lot_type.id,
      current_user: current_user,
      bidding_method: current_user.bidding_method
    }
  end

  def check_if_breaked_lot
    moq_sub_lot_status = LookupValue.find_by(code: Rails.application.credentials.lot_status_moq_sub_lot_pending_decision)
    if @liquidation_order.moq_sub_lots.where.not(status: moq_sub_lot_status.original_code).any?
      render_error("Lot can't be republish due to all sub lots are not in pending decision.", 422)
    end
  end
end
