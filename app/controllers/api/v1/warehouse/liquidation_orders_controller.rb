class Api::V1::Warehouse::LiquidationOrdersController < ApplicationController

  skip_before_action :authenticate_user!, only: [:update_lot_beam_status]
  skip_before_action :check_permission, only: [:update_lot_beam_status, :extend_time]
  

  # GET /api/v1/warehouse/liquidation_orders
  def index
    set_pagination_params(params)
    @liquidation_orders = LiquidationOrder.includes(:liquidations).where.not(status: 'Dispatched').where(liquidations: {distribution_center_id: current_user.distribution_centers.collect(&:id)})
    @liquidation_orders = @liquidation_orders.where(id: params[:lot_id]) if params[:lot_id].present?
    @liquidation_orders = @liquidation_orders.where("liquidation_orders.lot_name ILIKE ?", "%#{ ActiveRecord::Base.sanitize_sql_like(params[:lot_name]) }%") if params[:lot_name].present?
    @liquidation_orders = send(params[:lot_type]+"_lots") if params[:lot_type].present?

    @liquidation_orders = @liquidation_orders.order(created_at: :desc).page(@current_page).per(@per_page)
    render json: @liquidation_orders, meta: pagination_meta(@liquidation_orders)
  rescue Exception => message
    render json: { errors: message.to_s }, status: 500
  end

  def beam_orders
    set_pagination_params(params)
    lot_type = LookupValue.find_by(code: Rails.application.credentials.liquidation_lot_type_beam_lot)
    @liquidation_orders = LiquidationOrder.includes(:liquidations, :warehouse_orders, :liquidation_order_histories, :quotations).where(lot_type_id: lot_type.id, liquidations: {distribution_center_id: current_user.distribution_centers}).order(created_at: :desc).page(@current_page).per(@per_page)
    render json: @liquidation_orders, meta: pagination_meta(@liquidation_orders)
  end

  def delete_lot
    liquidation_item = LiquidationOrder.includes(:liquidations).where("id = ?", params[:id]).first
    if liquidation_item.liquidations.present?
      if liquidation_item.lot_type == 'Beam Lot'
        pending_status = LookupValue.find_by(code: Rails.application.credentials.lot_status_pending_publish)
        if liquidation_item.status_id != pending_status.id
          liquidation_item.status = pending_status.original_code
          liquidation_item.status_id = pending_status.id
          details = Hash.new
          details['lot_name'] = liquidation_item.lot_name
          liquidation_item.details["deleted_by_user_id"] = current_user.id
          liquidation_item.details["deleted_by_user_name"] = current_user.full_name
          liquidation_item.details['reason_to_cancel'] = params['remark']
          liquidation_item.save
          BeamLotMailer.cancel_lot(details).deliver_now
        end
        serializable_resource = {lot_name: liquidation_item.lot_name, lot_id: liquidation_item.beam_lot_id}.as_json
        if liquidation_item.save
          url =  Rails.application.credentials.beam_url+"/api/lots/cancel_lot"
          response = RestClient::Request.execute(method: :post, url: url, payload: serializable_resource, verify_ssl: OpenSSL::SSL::VERIFY_NONE)        
        end
      elsif liquidation_item.lot_type == 'Email Lot'
        status = LookupValue.where(code: Rails.application.credentials.lot_status_pending_closure).last
        lot = LiquidationOrder.find_by_id(params[:id])
        details = {}
        details["deleted_by_user_id"] = current_user.id
        details["deleted_by_user_name"] = current_user.full_name
        details['reason_to_cancel'] = params['remark']
        lot.update_attributes(status: status.original_code, status_id: status.id, winner_code: nil, winner_amount: nil, payment_status: nil, payment_status_id: nil, amount_received: nil, dispatch_ready: nil, details: {})
        BeamLotMailer.email_lot_cancel(liquidation_item.id).deliver_now
      end
      render json: "success" , status: 200
    else
      render json: "error", status: 422
    end

  end

  def relive_lot
    status = LookupValue.where(code: Rails.application.credentials.lot_status_pending_closure).last
    lot = LiquidationOrder.find_by_id(params[:id])
    lot.update_attributes(status: status.original_code, status_id: status.id, winner_code: nil, winner_amount: nil, payment_status: nil, payment_status_id: nil, amount_received: nil, dispatch_ready: nil, details: {})
    lot.update_liquidation_status('create_lots', current_user)
    render json: "success" , status: 200
  end

  def winner_code_list
    vendor_master_ids =  LiquidationOrderVendor.where(liquidation_order_id: params[:id]).pluck(:vendor_master_id)
    @vendor_code = VendorMaster.find(vendor_master_ids).pluck(:vendor_code)
    render json: @vendor_code
  end  

  # fetch inventory
  def lot_inventory
    @liquidation_item = LiquidationOrder.find(params[:id]).liquidations
    render json: @liquidation_item
  end

  def publish_lot
    begin
      ActiveRecord::Base.transaction do
        liquidation_order = LiquidationOrder.where("id = ?", params[:id]).first
        response = liquidation_order.publish_to_beam(current_user)
        liquidation_order.publish_to_reseller(current_user)
        render json: liquidation_order
      end
    rescue Exception => message
      render json: { errors: message.to_s }, status: 500
    end
  end

  def update_lot_beam_status
    liquidation_order = LiquidationOrder.where(lot_name: params[:bid_name]).first
    if liquidation_order.present?
      if params[:status] == "200"
        lot_status_in_progress = LookupValue.where(code: Rails.application.credentials.lot_status_in_progress_b2b).last
        if liquidation_order.update(status: lot_status_in_progress.original_code, status_id: lot_status_in_progress.id, beam_lot_response: "Success", beam_lot_id: params[:beam_lot_id])
          liquidation_order.update_liquidation_status('update_lot_beam_status', current_user)
          liquidation_order_history = LiquidationOrderHistory.create(liquidation_order_id:liquidation_order.id, status: lot_status_in_progress.original_code, status_id: lot_status_in_progress.id)
        end
        render json: liquidation_order
      else
        liquidation_order.update(beam_lot_response: params[:error_message])
        render json: liquidation_order
      end
    else
      render json: {error: "Error in fetching lot"}, status: 500
    end
  end

  def get_lot_details
    liquidation_order = LiquidationOrder.where("id = ?", params[:id]).first
    render json: liquidation_order, serializer: LotDetailSerializer
  end

  def extend_lot_mail
    begin
      ActiveRecord::Base.transaction do
        liquidation_order = LiquidationOrder.find(params[:id])
        liquidation_order.update(end_date: params[:end_date])
        details = Hash.new
        details['lot_name'] = liquidation_order.lot_name
        details['end_date'] = liquidation_order.end_date
        BeamLotMailer.extend_lot(details).deliver_now
      end # transaction end
      render json: "success"
    rescue  Exception => message
      render json: { errors: message.to_s }, status: 500
    end # rescue end
  end

  def extend_time
    begin
      ActiveRecord::Base.transaction do
        if params[:end_date].present? && params[:end_date].to_datetime >= Time.now
          lot = LiquidationOrder.find(params[:id])
          # beam API starts
          url =  Rails.application.credentials.beam_url+"/api/lots/extend_lot"
          serializable_resource = {lot_id: lot.beam_lot_id, lot_name: lot.lot_name, end_date: params[:end_date]}.as_json
          response = RestClient::Request.execute(method: :post, url: url, payload: serializable_resource, verify_ssl: OpenSSL::SSL::VERIFY_NONE)
          # beam API ends
          parsed_response = JSON.parse(response)
          if parsed_response.present? && parsed_response["status"] == "500"
            render json: { errors: parsed_response["errors"] }, status: 500
          else
            lot.update(end_date: params[:end_date])
            render json: { message: "success" }, status: 200
          end
        else
          render json: { errors: "Selected date cannot be less than today." }, status: 500
        end
      end # transaction end
    rescue Exception => message
      render json: { errors: message.to_s }, status: 500
    end
  end

  def cancel_lot_mail
    begin
      ActiveRecord::Base.transaction do
        liquidation_order = LiquidationOrder.find(params[:id])
        @liquidation_items = liquidation_order.liquidations
        new_liquidation_status = LookupValue.find_by(code: 'liquidation_status_pending_liquidation')
        @liquidation_items.each do |liquidation|
          liquidation.update!( lot_name: "", liquidation_order_id: "" , status: new_liquidation_status.original_code , status_id: new_liquidation_status.id )
          details = current_user.present? ? { status_changed_by_user_id: current_user.id, status_changed_by_user_name: current_user.full_name } : {}
          LiquidationHistory.create(
            liquidation_id: liquidation.id, status_id: new_liquidation_status.id, status: new_liquidation_status.original_code ,
            created_at: Time.now, updated_at: Time.now, details: details
          )
        end
        liquidation_order.details["deleted_by_user_id"] = current_user.id
        liquidation_order.details["deleted_by_user_name"] = current_user.full_name
        liquidation_order.save
        if liquidation_order.lot_type ==  "Beam Lot"
          serializable_resource = {lot_name: liquidation_order.lot_name, lot_id: liquidation_order.beam_lot_id}.as_json
          url =  Rails.application.credentials.beam_url+"/api/lots/cancel_lot"
          response = RestClient::Request.execute(method: :post, url: url, payload: serializable_resource, verify_ssl: OpenSSL::SSL::VERIFY_NONE)
        end
        liquidation_order.delete
      end # transaction end
      render json: "success"
    rescue  Exception => message
      render json: { errors: message.to_s }, status: 500
    end # rescue end
  end

  def send_email_to_vendors
    set_pagination_params(params)
    selected_liquidation_orders = LiquidationOrder.where(id: params[:liquidation_order_ids])
    date_empty = selected_liquidation_orders.collect(&:end_date).any?{ |e| e.nil? }
    price_empty = selected_liquidation_orders.collect(&:order_amount).any?{ |e| e.nil? }
    if date_empty || price_empty
      render json: { errors: "Please verify Date and Price for the selected lots" }, status: 500
    else
      selected_liquidation_orders.each do |liquidation_order|
        liquidation_order.details['email_sent'] = true
        liquidation_order.details['published_at'] = Time.now.in_time_zone('Mumbai').strftime("%d/%b/%Y - %I:%M %p")
        liquidation_order.details['set_inventory_status'] = true
        if liquidation_order.save
          liquidation_order.update_liquidation_status('update_lot_beam_status', current_user)
        end
        VendorMaster.where(vendor_code: params[:vendor_codes]).each do |vendor_m_id|
          lov = LiquidationOrderVendor.create(liquidation_order_id: liquidation_order.id, vendor_master_id:vendor_m_id.id)
          lov.create_vendor_quotation_links(get_host) if lov.present?
        end
      end
      # Return Items
      lot_status_partial_payment = LookupValue.where(code: Rails.application.credentials.lot_status_partial_payment).last
      lot_status_full_payment_received = LookupValue.where(code: Rails.application.credentials.lot_status_full_payment_received).last
      lot_status_dispatch_ready = LookupValue.where(code: Rails.application.credentials.lot_status_dispatch_ready).last
      pending_closure = LookupValue.where(code: Rails.application.credentials.lot_status_pending_closure).last
      @liquidation_orders = LiquidationOrder.includes(:liquidations, :warehouse_orders, :liquidation_order_histories, :quotations).where(status_id: [lot_status_partial_payment.id, lot_status_full_payment_received.id, lot_status_dispatch_ready.id, pending_closure.id], liquidations: {distribution_center_id: current_user.distribution_centers}).order(updated_at: :desc).page(@current_page).per(@per_page)
      render json: @liquidation_orders.uniq, root: 'liquidation_orders', meta: pagination_meta(@liquidation_orders)
    end
  end

  def approve_contract_lot
    liquidation_order = LiquidationOrder.where(id: params[:liquidation_order_id]).includes(:liquidations).last
    vendor_master = VendorMaster.where(vendor_code: params[:vendor_code]).includes(:vendor_rate_cards).last
    missing_rate_card = false
    winner_amount = 0
    liquidation_order.liquidations.each do |liquidation|
      rate_card = vendor_master.vendor_rate_cards.find_by(sku_master_code: liquidation.sku_code, item_condition: liquidation.grade)
      if rate_card
        winner_amount += rate_card.contracted_rate
      else
        missing_rate_card = true
        break
      end
    end
    if missing_rate_card
      render json: { errors: "Please update rate card." }, status: 500
    else
      order_status = LookupValue.where(code: Rails.application.credentials.lot_status_confirmation_pending).last
      begin
        ActiveRecord::Base.transaction do
          liquidation_order.status = order_status.original_code
          liquidation_order.status_id = order_status.id
          liquidation_order.winner_code = vendor_master.vendor_code
          liquidation_order.vendor_code = vendor_master.vendor_code
          liquidation_order.winner_amount = winner_amount
          liquidation_order.start_date = Time.now.strftime("%F %I:%M:%S %p")
          liquidation_order.end_date = Time.now.strftime("%F %I:%M:%S %p")
          if liquidation_order.save
            liquidation_order.update_liquidation_status('create_bids', current_user)
            LiquidationOrderHistory.create(liquidation_order_id: liquidation_order.id, status: liquidation_order.status, status_id: liquidation_order.status_id)
          end
        end
        render json: liquidation_order
      rescue Exception => message
        render json: { errors: message.to_s }, status: 500
      end
    end
  end

  def get_contracted_price
    liquidation_order = LiquidationOrder.where(id: params[:liquidation_order_id]).includes(:liquidations).last
    vendor_master = VendorMaster.where(vendor_code: params[:vendor_code]).includes(:vendor_rate_cards).last
    contracted_price = 0
    liquidation_order.liquidations.each do |liquidation|
      rate_card = vendor_master.vendor_rate_cards.find_by(sku_master_code: liquidation.sku_code, item_condition: liquidation.grade)
      next unless rate_card
      contracted_price += rate_card.contracted_rate
    end
    render json: { contracted_price: contracted_price }, status: 200
  end

  def get_quotations
    liquidation_order = LiquidationOrder.find(params[:id])
    @quotations = liquidation_order.quotations
    render json: @quotations
  end

  def pending_publish_lots
    @liquidation_orders.with_status(['Pending Publish', 'Pending Closure']).or(@liquidation_orders.with_lot_type('Email Lot').not_emailed)
  end

  def in_progress_lots
    active_liquidation_ids = @liquidation_orders.emailed.select { |liquidation| !liquidation.is_expired? }.map(&:id)
    @liquidation_orders.with_status(['In Progress', 'Pending Closure']).or(@liquidation_orders.with_lot_type('Email Lot').where(id: active_liquidation_ids))
  end

  def decision_pending_lots
    inactive_liquidation_ids = @liquidation_orders.emailed.select { |liquidation| liquidation.is_expired? }.map(&:id)
    @liquidation_orders.with_status(['Confirmation Pending', 'Partial Payment', 'No Bid', 'Full Payment Received', 'Pending Closure']).or(@liquidation_orders.where(id: inactive_liquidation_ids).where.not(status: 'Dispatch Ready')).or(@liquidation_orders.with_status('Pending Closure').with_lot_type('Manual Dispatch Lot'))
  end

  def dispatch_ready_lots
    @liquidation_orders.with_status('Dispatch Ready')
  end
end

