class VendorRateCardWorker
  include Sidekiq::Worker
  def perform(current_user_id, vendor_master_id)
    VendorMailer.rate_card_report(current_user_id, vendor_master_id).deliver_now
  end
end