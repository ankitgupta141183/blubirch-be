class ReminderMailer < ApplicationMailer
	default from: 'reportguy@blubirch.com'

	def approval_email(details)
		#@email_details = params[:email_details]
		@email_details = details
    details = {return_request_number: @email_details['rrn_no'].to_s, invoice_number: @email_details['invoice_no'].to_s, return_reason: @email_details['return_reason'].to_s }
		@template = EmailTemplate.where(id: @email_details['email_template_id']).first
		@result = Reminder.parse_template(@template.template.html_safe,details)
    mail(to: @email_details['approve_email_id'], bcc: @email_details['copy_email_id'], subject: 'Return Request Approval')
  end

  def escalation_email
  	@email_details = params[:email_details]
  	details = {return_request_number: @email_details['rrn_no'].to_s, invoice_number: @email_details['invoice_no'].to_s, return_reason: @email_details['return_reason'].to_s }
  	@template = EmailTemplate.where(id: @email_details['email_template_id']).first
  	@result = Reminder.parse_template(@template.template.html_safe,details)
  	mail(to: @email_details['escalation_email_id'], bcc: @email_details['escalation_copy_email_id'], subject: 'Return Request Escalation')
  end

  def reminder_email
  	@email_details = params[:email_details]
  	details = {return_request_number: @email_details['rrn_no'].to_s, invoice_number: @email_details['invoice_no'].to_s, return_reason: @email_details['return_reason'].to_s }
  	@template = EmailTemplate.where(id: @email_details['email_template_id']).first
  	@result = Reminder.parse_template(@template.template.html_safe,details)
  	mail(to: @email_details['reminder_email_id'], bcc: @email_details['reminder_copy_email_id'], subject: 'Return Request Reminder')
  end


  def rtv_email(files_name, rtv_id)
    rtv_alert = RtvAlert.find_by_id(rtv_id)
    @email_body = rtv_alert.body
      if files_name.present?
        files_name.each do |f|
          attachments["#{f.original_filename}"] = File.read(f.tempfile)
        end
      end

    mail(to: rtv_alert.recipient_email, bcc: "rohithkr@blubirch.com", subject: rtv_alert.subject)
  end


  def liquidation_email(csv, email_id)   
    attachments['liquidation_inventories.csv'] = {mime_type: 'text/csv', content: csv}

    mail(to: email_id, bcc: "rohithkr@blubirch.com", subject: "File listing for items marked for liquidation")
  end

  def e_waste_email(csv, email_id)   
    attachments["e_waste_file_#{Time.now.to_datetime.strftime('%Y-%m-%dT%H:%M:%S').to_s}.csv"] = {mime_type: 'text/csv', content: csv}

    mail(to: email_id, bcc: "rohithkr@blubirch.com", subject: "File listing for items marked for e-waste")
  end

  def claim_created(claim)
    @body = "<p>Dear Sir,</p> <br> <br> <br> This emailer is to remind you for approving the attached item list. "
    mail(to: claim.distribution_center.users.first.email, subject: "")
  end

  def reset_password_email(email_id,otp)
    @otp = otp
    mail(to: email_id, subject: "OTP Verification to Reset Password")
  end
	
	def insurance_admin_email(details)
		details.stringify_keys!
		@base_url = details['base_url']
		@tag_number = details['tag_number']
		mail(to: details['email'], subject: "Insurance Item moved to Pending Disposition.")
	end
	
	def insurance_reject_email(details)
		details.stringify_keys!
		@base_url = details['base_url']
		@tag_number = details['tag_number']
		mail(to: details['email'], subject: "Insurance Item Disposition Rejected.")
	end
end
