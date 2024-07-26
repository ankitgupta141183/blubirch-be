class VendorMailerWorker
  include Sidekiq::Worker
  sidekiq_options :retry => false

  def perform(vendor_master_id, token, host, liquidation_order_id)
    VendorMailer.send_email_for_quotation(vendor_master_id, token, host, liquidation_order_id).deliver_now
  end
end