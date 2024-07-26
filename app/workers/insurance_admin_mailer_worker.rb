class InsuranceAdminMailerWorker
  include Sidekiq::Worker
  sidekiq_options :retry => false

  def perform(details)
    ReminderMailer.insurance_admin_email(details).deliver_now
  end
end