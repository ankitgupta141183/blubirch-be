class QuotationSerializer < ActiveModel::Serializer
  
  attributes :id, :lot_name, :expected_price, :vendor_name, :vendor_master_id, :vendor_code, :created_at, :vendor_email

  def lot_name
  	object.liquidation_order.lot_name rescue ''
  end

  def expected_price
    if ((object.liquidation_order.start_date_with_localtime.to_datetime.strftime("%d/%b/%Y - %I:%M %p").to_datetime <= Time.now.in_time_zone('Mumbai').to_datetime.strftime("%d/%b/%Y - %I:%M %p").to_datetime) && (object.liquidation_order.end_date_with_localtime.to_datetime.strftime("%d/%b/%Y - %I:%M %p").to_datetime >= Time.now.in_time_zone('Mumbai').to_datetime.strftime("%d/%b/%Y - %I:%M %p").to_datetime))
      return ""
    else
      return object.expected_price
    end
  end

  def vendor_name
  	object.vendor_master.vendor_name rescue ''
  end

  def vendor_code
  	object.vendor_master.vendor_code rescue ''
  end

  def vendor_email
  	object.vendor_master.vendor_email rescue ''
  end

  def created_at
    object.created_at.in_time_zone('Mumbai').strftime('%d/%m/%Y %H:%M %p') rescue ""
  end
  
end
