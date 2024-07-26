class Api::V2::Warehouse::LiquidationOrderIndexSerializer < ActiveModel::Serializer
  COMPETITIVE = 'Competitive Lot'
  MOQ = 'MOQ Lot'
  MOQSUBLOT = 'MOQ Sub Lot'

  attributes :id, :lot_name, :price_discovery_method, :status, :status_id, :start_date, :end_date, :vendor_code, :created_at, :updated_at, :publishable_status, :mrp, :is_expired, :selected_vendors, :republish_status, :lot_id

  def start_date
    object.start_date_with_localtime.strftime('%d/%m/%Y %H:%M %p') rescue ""
  end

  def end_date
    object.end_date_with_localtime.strftime('%d/%m/%Y %H:%M %p') rescue ""
  end

  def created_date
    object.created_at.strftime('%d/%m/%Y')
  end

  def price_discovery_method
    case object.lot_type
    when COMPETITIVE
      'Competitive Bidding'
    when MOQ, MOQSUBLOT
      'MOQ'
    end
  end

  def lot_id
    object.is_moq_sub_lot? ? "#{object.moq_order_id}-#{object.lot_order.to_s.rjust(2, '0')}" : object.id
  end

  def is_expired
    object.is_expired?
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

  def republish_status
    object.can_be_publish? ? object.republish_status : 'error'
  end

  def selected_vendors
    object.details["vendor_lists"] rescue []
  end
end
