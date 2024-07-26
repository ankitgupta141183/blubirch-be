class PrdMailerWorker
  include Sidekiq::Worker

  def perform(file_csv, filename, subject, email_ids)
    PrdMailer.send_prd_items(file_csv, filename, subject, email_ids).deliver_now
  end
end