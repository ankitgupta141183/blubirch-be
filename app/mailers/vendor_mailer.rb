class VendorMailer < ApplicationMailer
	default from: 'reportguy@blubirch.com'

  def send_email_for_quotation(vendor_master_id, token, host, liquidation_order_id)
    liquidation_order = LiquidationOrder.find(liquidation_order_id)
    vendor_master = VendorMaster.find(vendor_master_id)
    subject = "Provide your Quotation For Lot #{liquidation_order.lot_name}"
    @url = "#{host}/api/v1/quotation?token=#{token}"
    @body = "<p>Dear Sir,</p> <br> <br> Lot Name - #{liquidation_order.lot_name} <br> End Date - #{ liquidation_order.end_date_with_localtime.strftime("%d/%b/%Y - %I:%M %p") } <br> Amount - #{liquidation_order.order_amount} <br> Quantity - #{liquidation_order.quantity} <br> Please click url to provide Quotation. #{@url}"
    mail(to: vendor_master.vendor_email, subject: subject)
  end

  def rate_card_report(user_id, vendor_master_id)
    user = User.find_by(id: user_id)
    subject = "Vendor Rate Card"
    link = VendorRateCard.to_csv(vendor_master_id)
    body = "<p>Dear Sir,</p> <br> <br> Please click below url to download report <br> #{link} "
    mail(to: user.email, subject: subject, body: body)
  end 

  def liquidation_data_email(url, user)
    subject = "Liquidation Items CSV file"
    @body = "<p>Hi #{user.username},</p> <br> <br> <br> Please click url to download Liquidation Items file #{url} <br>"
    mail(to: user.email, subject: subject)
  end
end