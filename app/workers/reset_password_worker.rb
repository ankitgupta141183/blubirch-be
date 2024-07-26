class ResetPasswordWorker
	include Sidekiq::Worker

	def perform(email_id,otp)
		ReminderMailer.reset_password_email(email_id,otp).deliver_now
	end
end