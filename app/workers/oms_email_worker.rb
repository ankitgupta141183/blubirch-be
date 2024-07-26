class OmsEmailWorker
	include Sidekiq::Worker

	def perform(order_management_system, vendor)
    OmsVendorMailer.send_email_for_oms_order(order_management_system, vendor).deliver_now
  end