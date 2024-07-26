class ReminderMailerWorker
	include Sidekiq::Worker

	def perform(details)
		ReminderMailer.approval_email(details).deliver_now
	end
end