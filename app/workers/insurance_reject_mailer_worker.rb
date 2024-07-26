class InsuranceRejectMailerWorker
  include Sidekiq::Worker
  sidekiq_options :retry => false

  def perform(details)
    ReminderMailer.insurance_reject_email(details).deliver_now
  end
end