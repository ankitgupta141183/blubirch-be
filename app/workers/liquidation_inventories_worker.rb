class LiquidationInventoriesWorker
	include Sidekiq::Worker

	def perform(user_id)
		user = User.find(user_id)
		email = user.email
		# email = "subbiah@blubirch.com"
		ReminderMailer.liquidation_email(Liquidation.to_csv(user_id),email).deliver_now 
	end
end