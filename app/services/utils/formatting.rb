module Utils::Formatting

  # formatted date based on the date object
  def format_date(date, format = :p_date1, blank = "")
    date.blank? ? blank : date.to_s(format)
  end

  # formatted time based on the time object
  def format_time(time, format = :p_long, blank = "")
    time.blank? ? blank : time.to_s(format)
  end
  
  def format_ist_time(time, format = :p_long, blank = "")
    time.blank? ? blank : time.in_time_zone("Asia/Calcutta").to_s(format)
  end

  # converts the number into two decimal format by default or as per decimals
  def to_rounded(number, decimals: 2)
    number.to_f.round(decimals.to_i)
  end

  def self.to_rounded(number, decimals: 2)
    number.to_f.round(decimals.to_i)
  end

  def formatted_current_time 
    Time.current.to_fs(:pd_long)
  end

  def time_difference(end_time, expected_min)
    ((Time.parse(Time.current.to_s) - Time.parse(end_time.to_s))/3600.to_f).to_f > expected_min.to_f
  end

  def format_number(number)
    whole_number, decimal_number = number.to_s.split('.')
    num_groups = whole_number.to_s.chars.to_a.reverse.each_slice(3)
    formatted_whole_number = num_groups.map(&:join).join(',').reverse
    (decimal_number.to_f <= 0.0) ? "#{formatted_whole_number}" : "#{formatted_whole_number}.#{decimal_number}"
  end
end