class DashboardMappingWorker
  include Sidekiq::Worker

  def perform(*)
    AlertConfiguration.update_disposition_dashboard_count
    AlertConfiguration.update_inventory_dahsboard_count
  end
end
