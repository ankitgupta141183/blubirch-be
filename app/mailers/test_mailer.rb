class TestMailer < ApplicationMailer
  default from: 'reportguy@blubirch.com'

  def run_test(email = nil)
    return unless email

    subject = "Testing"
    body = "<p>Dear Sir,</p> <br> <br> This is the test email."

    mail(to: email, subject: subject, body: body)
  end
end
