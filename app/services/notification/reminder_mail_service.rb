# frozen_string_literal: true

module Notification
  class ReminderMailService < BaseService
    def reset_password(email, otp)
      @notification_name = 'reset_otp'
      @recipient = email
      @custom_data = {
        "otp": otp
      }
      trigger_api_sync
    end

    def approval_email(email_details)
      @notification_name = 'approval_email'
      details = {return_request_number: email_details['rrn_no'].to_s, invoice_number: email_details['invoice_no'].to_s, return_reason: email_details['return_reason'].to_s }
      template = EmailTemplate.where(id: email_details['email_template_id']).first
      result = Reminder.parse_template(template.template.html_safe, details)
      @custom_data = {
        template: result
      }
      @recipient = email_details['approve_email_id']
      @bcc_recipient = email_details['copy_email_id']
      trigger_api_sync
    end

    def reminder_email(params)
      email_details = params[:email_details]
      details = {return_request_number: email_details['rrn_no'].to_s, invoice_number: email_details['invoice_no'].to_s, return_reason: email_details['return_reason'].to_s }
      template = EmailTemplate.where(id: email_details['email_template_id']).first
      result = Reminder.parse_template(template.template.html_safe, details)
      @recipient = email_details['reminder_email_id']
      @bcc_recipient = email_details['reminder_copy_email_id']
      @custom_data = {
        result: result
      }
      trigger_api_sync
    end

    def e_waste_email(user_id)
      ewaste_csv = EWaste.to_csv(user_id)
      time = Time.now.strftime("%F %H:%M:%S").to_s.tr('-', '')
      ewaste_url = export_to_aws(ewaste_csv, "ewaste_csv_#{time.parameterize.underscore}.csv")
      @notification_name = 'e_waste_email'
      user = User.find_by(id: user_id)
      @recipient = user.email
      @bcc_recipient = "rohithkr@blubirch.com"
      @custom_data = {
        url: ewaste_url
      }
      trigger_api_sync
    end

    def liquidation_email
      csv = Liquidation.to_csv(user_id)
      time = Time.now.strftime("%F %H:%M:%S").to_s.tr('-', '')
      csv_url = export_to_aws(csv, "liquidation_csv_#{time.parameterize.underscore}.csv")
      @notification_name = 'liquidation_email'
      user = User.find_by(id: user_id)
      @recipient = user.email
      @bcc_recipient = "rohithkr@blubirch.com"
      @custom_data = {
        url: ewaste_url
      }
      trigger_api_sync
    end

    def rtv_email
      
    end
  end
end

