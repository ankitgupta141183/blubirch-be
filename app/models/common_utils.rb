module CommonUtils

  def self.format_date(date)
    date.strftime('%Y-%m-%d')
  end

  # CommonUtils.run_test_mail(email = nil)
  def self.run_test_mail(email = nil)
    TestMailer.run_test(email).deliver_now if email
  end

  def self.get_current_local_time
    Time.now.in_time_zone('Mumbai')
  end

end
