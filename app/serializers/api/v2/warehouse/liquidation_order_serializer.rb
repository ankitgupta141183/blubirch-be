class Api::V2::Warehouse::LiquidationOrderSerializer < ActiveModel::Serializer
  COMPETITIVE = 'Competitive Lot'
  MOQ = 'MOQ Lot'
  MOQSUBLOT = 'MOQ Sub Lot'

  attributes :id, :order_number, :vendor_code, :order_amount, :created_at, :updated_at, :ai_price, :lot_name, :lot_desc, :mrp, :end_date, :status, :status_id, :winner_code, :winner_amount, :payment_status, :payment_status_id, :amount_received, :dispatch_ready, :quantity, :lot_category, :approved_buyer_ids, :start_date, :floor_price, :reserve_price, :email_sent, :bid_count, :alert_level, :lot_image_urls, :lot_type, :dispatch_date, :invoice_number, :serial_number, :invoice_value, :buy_now_price, :increment_slab, :created_date, :is_expired, :warehouse_order_status, :remarks, :bill_to, :inventory_deleted, :winner_amount_reason, :selected_vendors, :republish_status, :uniq_bids_no, :higest_bid, :delivery_timeline, :additional_info, :bid_value_multiple_of, :buyer_name, :so_number, :purchase_amount, :payments, :price_discovery_method, :sub_lot_quantity, :price_range, :maximum_lots_per_buyer, :lot_id, :beam_lot_id, :beam_lot_response, :publishable_status, :possible_sub_lots

  def sub_lot_quantity
    return [] unless object.is_moq_lot?
    object.details['sub_lot_quantity'].to_a
  end

  def price_range
    return [] unless object.is_moq_lot?
    object.moq_sub_lot_prices.select(:from_lot, :to_lot, :price_per_lot)
  end

  def dispatch_ready
    object&.dispatch_ready ? "Yes" : "No"
  end

  def invoice_number
    if object.warehouse_orders.present?
      object.details['outward_invoice_number']
    end
  end

  def serial_number
    object.details['serial_number']
  end

  def approved_buyer_ids
    object.details&.dig('approved_buyer_ids') || []
  end

  def invoice_value
    object.details['invoice_value'] rescue ""
  end

  def start_date
    object.start_date_with_localtime.strftime('%d/%m/%Y %H:%M %p') rescue ""
  end

  def end_date
    object.end_date_with_localtime.strftime('%d/%m/%Y %H:%M %p') rescue ""
  end

  def email_sent
    object.details['email_sent'].present?
  end

  def bid_count
    object.lot_type == 'Email Lot' ? object.quotations.size : object.bids.size
  end

  def alert_level
    'Low'
  end

  def created_date
    object.created_at.strftime('%d/%m/%Y')
  end

  def warehouse_order_status
    if object.warehouse_orders.present?
      status = LookupValue.where(id: object.warehouse_orders.last.status_id).last
      case status&.original_code
      when 'Pending Pick'
        'Pending Pick-Up'
      when 'Pending Pack'
        'Pending Packaging'
      when 'Pending Dispatch'
        'Pending Dispatch'
      else
        "N/A"
      end
    else
      "N/A"
    end
  end

  def is_expired
    object.is_expired?
  end

  def bill_to
    object&.details.dig("billing_to_id")
  end

  def inventory_deleted
    object.details['items_deleted'].present?
  end

  def winner_amount_reason
    object.details['winner_amount_update_reason'] rescue ''
  end

  def selected_vendors
    object.details["vendor_lists"] rescue []
  end

  def uniq_bids_no
    if ['Beam Lot', 'Competitive Lot'].include?(object.lot_type)
      object.bids.group_by(&:user_name).count
    elsif object.lot_type == 'Email Lot'
      object.quotations.group_by(&:vendor_master).count
    end
  end

  def higest_bid
    object.bids.pluck(:bid_price).max rescue 'N/A'
  end

  def dispatch_date
    object.details["dispatch_date"] rescue ""
  end

  def price_discovery_method
    case object.lot_type
    when COMPETITIVE
      'Competitive Bidding'
    when MOQ, MOQSUBLOT
      'MOQ'
    end
  end

  def so_number
    object.details["so_number"] rescue ""
  end

  def purchase_amount
    object.winner_amount
  end

  def payments
    object.details["payments"] rescue ""
  end

  def lot_id
    object.is_moq_sub_lot? ? "#{object.moq_order_id}-#{object.lot_order.to_s.rjust(2, '0')}" : object.id
  end

  def republish_status
    object.can_be_publish? ? object.republish_status : 'error'
  end

  def publishable_status
    if object.republish_status == 'error'
      object.beam_lot_response
    elsif object.republish_status == 'pending'
      'Please wait, publishing the lot'
    elsif object.status == 'Creating Sub Lots'
      object.status
    else
      object.can_be_publish? ? object.status : 'Pending Lot Details'
    end
  end

  def possible_sub_lots
    object.available_sub_lot.count rescue ""
  end
end
