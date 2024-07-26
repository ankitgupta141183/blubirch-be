class RtvMailerWorker
  include Sidekiq::Worker

  def perform(files_name, rtv_alert_record_id)
    ReminderMailer.rtv_email(files_name, rtv_alert_record_id).deliver_now
  end
  
end