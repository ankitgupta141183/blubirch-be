class LiquidationOrderVendor < ApplicationRecord
  # acts_as_paranoid
  belongs_to :liquidation_order
  belongs_to :vendor_master

  def create_vendor_quotation_links(host)
    token = SecureRandom.urlsafe_base64(nil, false)
    link = VendorQuotationLink.new(vendor_master_id: vendor_master.id, liquidation_order_id: liquidation_order.id,
     expiry_date: liquidation_order.end_date, token: token)

    if link.save
      VendorMailerWorker.perform_async(link.vendor_master_id, link.token, host, link.liquidation_order_id)
      # VendorMailer.send_email_for_quotation(link.vendor_master_id, link.token).deliver_now
    end

  end

end
