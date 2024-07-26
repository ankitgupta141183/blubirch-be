# frozen_string_literal: true

module Notification
  class ReportService < BaseService

    def inbound_documents_email(type, url, user_id, email, time)
      @notification_name = 'inbound_documents_email'
      @recipient = email || User.find_by_id(user_id).email
      @custom_data = {
        "url": url,
        "time": time
      }
      trigger_api_sync
    end

    def visiblity_email(type, url, user_id=nil, email=nil, time=nil)
      @notification_name = 'visiblity_email'
      @recipient = report_recipients
      @custom_data = {
        "url": url,
        "time": time
      }
      trigger_api_sync
    end

    def send_daily_reports(url, report_type, time)
      @notification_name = 'daily_report'
      @recipient = report_recipients
      @custom_data = {
        "url": url,
        "time": time,
        "report_type": report_type
      }
      trigger_api_sync
    end

    def send_monthly_timeline_report(url, report_type, time)
      @notification_name = 'monthly_timeline_report'
      @recipient = report_recipients
      @custom_data = {
        "url": url,
        "time": time,
        "report_type": report_type
      }
      trigger_api_sync
    end

    def send_daily_timeline_report(url, report_type, time)
      @notification_name = 'send_daily_timeline_report'
      @recipient = report_recipients
      @custom_data = {
        "url": url,
        "time": time,
        "report_type": report_type
      }
      trigger_api_sync
    end

    private

    def report_recipients
      ["ravisathyajith@blubirch.com", "viswanathan@blubirch.com", "rohithkr@blubirch.com", "Raviranjan.ray@croma.com", "rpaincharge@infinitiretail.com", "RPA_Manager@croma.com", "Reverse_Logistics_Team@Croma.com", "Sologistics@croma.com", "sologistics07@croma.com", "SupplychainDA@croma.com"]
    end
  end
end
