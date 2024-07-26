class ReturnRequestApprovalWorker
  include Sidekiq::Worker

  def perform(user_id, details)
    user = User.find_by_id(user_id) 
    ReturnRequestApprovalMailer.send_mail_to_store_user(user, details).deliver_now
  end
end