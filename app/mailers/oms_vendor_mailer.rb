class VendorMailer < ApplicationMailer
	default from: 'reportguy@blubirch.com'

  def send_email_for_oms_order(order_management_system, vendor)
    subject = "Provide Your Order for #{order_management_system.order_type} #{order_management_system.reason_reference_document_no}"
    @body = "<p> Dear Sir,</p> <br> <br> Order - #{order_management_system.reason_reference_document_no}"
    mail(to:vendor.vendor_poc_email, subject: subject)
  end    















   def send_email_for_quotation(vendor_master_id, token, host, liquidation_order_id)
    liquidation_order = LiquidationOrder.find(liquidation_order_id)
    vendor_master = VendorMaster.find(vendor_master_id)
    subject = "Provide your Quotation For Lot #{liquidation_order.lot_name}"
    @url = "#{host}/api/v1/quotation?token=#{token}"
    @body = "<p>Dear Sir,</p> <br> <br> Lot Name - #{liquidation_order.lot_name} <br> End Date - #{ liquidation_order.end_date_with_localtime.strftime("%d/%b/%Y - %I:%M %p") } <br> Amount - #{liquidation_order.order_amount} <br> Quantity - #{liquidation_order.quantity} <br> Please click url to provide Quotation. #{@url}"
    mail(to: vendor_master.vendor_email, subject: subject)
  end