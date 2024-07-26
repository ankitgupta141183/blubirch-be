class ReportMailer < ApplicationMailer
	default from: 'reportguy@blubirch.com'

  def visiblity_email(type, url, user_id=nil, email=nil, time)
    emails = ["ravisathyajith@blubirch.com", "viswanathan@blubirch.com", "Raviranjan.ray@croma.com", "rpaincharge@infinitiretail.com", "RPA_Manager@croma.com", "Reverse_Logistics_Team@Croma.com", "Sologistics@croma.com", "sologistics07@croma.com", "SupplychainDA@croma.com", "mohanprakash@blubirch.com", "sohanaj@blubirch.com"]
    emails = [User.find_by_id(user_id).email] if user_id.present?
    subject = "Visiblity Report" if type == 'visiblity'
    subject = "Outward Visiblity Report" if type == 'outward'
    subject = "Inward Report" if type == 'inward'
    subject = "File listing for items marked for liquidation" if type == 'liquidation_download'
    @body = "<p>Dear Sir,</p> <br> <br> <br> Please click url to  download report #{url} <br> This Report Generated at <b> #{time} </b>"
    emails += ['sohanaj@blubirch.com', 'lakshmanarao@blubirch.com', 'priyankag@blubirch.com', 'kavyabp@blubirch.com', 'chetanpatil@blubirch.com', 'prajwalhb@blubirch.com', 'manjunathbk@blubirch.com', 'sreejiths@blubirch.com'] if Rails.env == "development"
    mail(to: emails.uniq, subject: subject)
  end

  def send_daily_reports(url, report_type, time)
    emails = ["ravisathyajith@blubirch.com", "viswanathan@blubirch.com", "Raviranjan.ray@croma.com", "rpaincharge@infinitiretail.com", "RPA_Manager@croma.com", "Reverse_Logistics_Team@Croma.com", "Sologistics@croma.com", "sologistics07@croma.com", "SupplychainDA@croma.com", "mohanprakash@blubirch.com", "sohanaj@blubirch.com"]
    # emails = ["rohithkr@blubirch.com", "allwarehouse@yopmail.com", "testb@yopmail.com", "sankalpjoshi@blubirch.com", "sankalpjoshi555@gmail.com"]
    subject = "Daily Visibility Report" if report_type == "Inward"
    subject = "Daily Outward Visibility Report" if report_type == "Outward"
    @body = "<p>Dear Sir,</p> <br> <br> Please click below url to download #{(report_type == "Inward") ? "Visibility" : "Outward"} report <br> #{url} <br> This Report Generated at #{time}"
    mail(to: emails, subject: subject)
  end

  def send_monthly_timeline_report(url, report_type, time)
    # emails = ["rohithkr@blubirch.com", "ravisathyajith@blubirch.com"]
    emails = ["ravisathyajith@blubirch.com", "viswanathan@blubirch.com", "Raviranjan.ray@croma.com", "rpaincharge@infinitiretail.com", "RPA_Manager@croma.com", "Reverse_Logistics_Team@Croma.com", "Sologistics@croma.com", "sologistics07@croma.com", "SupplychainDA@croma.com", "mohanprakash@blubirch.com", "sohanaj@blubirch.com"]
    subject = "Monthly Timeline Report"
    @body = "<p>Dear Sir,</p> <br> <br> Please click below url to download #{report_type} report <br> #{url} <br> This Report Generated at #{time}"
    mail(to: emails, subject: subject)
  end

  def send_daily_timeline_report(url, report_type, time)
    # emails = ["rohithkr@blubirch.com", "ravisathyajith@blubirch.com"]
    emails = ["ravisathyajith@blubirch.com", "viswanathan@blubirch.com", "Raviranjan.ray@croma.com", "rpaincharge@infinitiretail.com", "RPA_Manager@croma.com", "Reverse_Logistics_Team@Croma.com", "Sologistics@croma.com", "sologistics07@croma.com", "SupplychainDA@croma.com", "mohanprakash@blubirch.com", "sohanaj@blubirch.com"]
    subject = "Daily Inward Report"
    @body = "<p>Dear Sir,</p> <br> <br> Please click below url to download #{report_type} report <br> #{url} <br> This Report Generated at #{time}"
    mail(to: emails, subject: subject)
  end

  def inbound_documents_email(type, url, user_id, email, time)
    email = User.find_by_id(user_id).email if email.blank?
    subject = "Inbound Documents Report" if type == 'inbound_documents'
    @body = "<p>Hi,</p> <br> <br> <br> Please click url to  download inbound documents report #{url} <br> This Report Generated at <b> #{time} </b>"
    mail(to: email, subject: subject)
  end

  def outbound_documents_email(type, url, user_id, email, time)
    email = User.find_by_id(user_id).email if email.blank?
    subject = "Outbound Documents Report" if type == 'outbound_documents'
    @body = "<p>Hi,</p> <br> <br> <br> Please click url to  download outbound documents report #{url} <br> This Report Generated at <b> #{time} </b>"
    mail(to: email, subject: subject)
  end

  def lot_closer_email(url)
    emails = ['nirbhay.singh1@croma.com', 'HimmatSingh.Bisht@croma.com', 'ravisathyajith@blubirch.com', 'Sriya.Chatterjee@croma.com', 'anildk@blubirch.com', 'meghae@blubirch.com', 'ankitpattnaik@blubirch.com', 'sunitav@blubirch.com', "mohanprakash@blubirch.com", "sohanaj@blubirch.com"]
    subject = "Croma Daily Auction Report"
    time = Time.now.in_time_zone('Mumbai').strftime("%F %I:%M:%S %p")
    @body = "<p>Dear Sir,</p> <br> <br> Please click below url to download report <br> #{url} <br> This Report Generated at #{time}"
    mail(to: emails, subject: subject)
  end

end
