class ReturnRequestApprovalMailer < ApplicationMailer
	default from: 'reportguy@blubirch.com'

  def send_mail_to_store_user(user, details)
    @user = user
    if details.present?
      @template = EmailTemplate.where(id: details['template_id']).last
      @result = Reminder.parse_template(@template.template.html_safe, details) 
    end
    mail(to: @user.email, subject: 'Request Approval Status')
  end

end
