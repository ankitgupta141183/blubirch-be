class DailyReportsWorker
  include Sidekiq::Worker

  def perform()
    inward_report_url = Inventory.export_inward_visibility_report
    ReportMailer.send_daily_reports(inward_report_url, 'Inward').deliver_now
    outward_report_url = Inventory.export_outward_visibility_report
    ReportMailer.send_daily_reports(outward_report_url, 'Outward').deliver_now
  end
end