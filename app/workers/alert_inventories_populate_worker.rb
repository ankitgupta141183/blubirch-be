class AlertInventoriesPopulateWorker
	include Sidekiq::Worker

	def perform()
		AlertConfiguration.check_for_bucket_records
	end
end