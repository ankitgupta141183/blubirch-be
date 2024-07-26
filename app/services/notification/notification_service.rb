# frozen_string_literal: true

module Notification
  class NotificationService < BaseService
    def cancel_lot(lot_name)
      @notification_name = 'cancel_lot'
      @recipient = Rails.application.credentials.beam_admin_mailid
      @custom_data = {
        lot_name: lot_name
      }
      trigger_api_sync
    end

    def email_lot_cancel(lot_id)
      lot = LiquidationOrder.with_deleted.find_by_id(lot_id)
      vendors = lot.vendor_quotation_links.pluck(:vendor_master_id)
      emails = VendorMaster.where(id: vendors).pluck(:vendor_email).compact
      emails = ['prajwalhb@blubirch.com', 'manjunathbk@blubirch.com'] if emails.blank?
      @notification_name = 'email_lot_cancel'
      @recipient = emails
      @custom_data = {
        lot_name: lot.lot_name
      }
      trigger_api_sync
    end

    # VERIFY
    def extend_lot(details)
      @notification_name = 'extend_lot'
      @recipient = Rails.application.credentials.beam_admin_mailid
      @custom_data = {
        lot_name: details['lot_name'],
        end_date: details['end_date']
      }
      trigger_api_sync
    end

    def send_mail_to_store_user(user, details)
      @notification_name = 'store_user_notification'
      @recipient = user.email
      result = ''
      if details.present?
        template = EmailTemplate.where(id: details['template_id']).last
        result = Reminder.parse_template(@template.template.html_safe, details)
      end
      @custom_data = {
        "user_name": user.username,
        "result": result
      }
      trigger_api_sync
    end

    def send_email_for_quotation(vendor_master_id, token, host, liquidation_order_id)
      liquidation_order = LiquidationOrder.find(liquidation_order_id)
      vendor_master = VendorMaster.find(vendor_master_id)
      @recipient = vendor_master.vendor_email
      @custom_data = {
        "lot_name": liquidation_order.lot_name,
        "end_date": liquidation_order.end_date_with_localtime.strftime("%d/%b/%Y - %I:%M %p"),
        "order_amount": liquidation_order.order_amount,
        "quantity": liquidation_order.quantity,
        "url": "#{host}/api/v1/quotation?token=#{token}"
      }
      trigger_api_sync
    end
  end
end
