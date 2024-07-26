class EWasteInventoriesWorker
	include Sidekiq::Worker

	def perform(current_user_id)
		user = User.find_by(id: current_user_id)
		ReminderMailer.e_waste_email(EWaste.to_csv(user.id),user.email).deliver_now 
	end
end