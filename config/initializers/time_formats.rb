# https://railsdatetimeformats.com/
# Time.zone.now.to_fs(:p_long)
# Date Formats 
Date::DATE_FORMATS[:p_short] = "%d %b" # 25 Mar
Date::DATE_FORMATS[:p_long] = "%d %b %Y" # 25 Mar 2021
Date::DATE_FORMATS[:p_date1] = "%d/%m/%Y" # 25/04/2021
Date::DATE_FORMATS[:p_date2] = "%d-%m-%Y" # 25-04-2021
Date::DATE_FORMATS[:p_date3] = "%Y-%m-%d" # 2021-04-25

# Time Formats 
Time::DATE_FORMATS[:p_short] = "%d %b %I:%M %P" # "25 Mar 11:54 am" 
Time::DATE_FORMATS[:p_long] = "%d/%m/%Y %I:%M %p" # "25 Mar 2021 11:54 am" 
Time::DATE_FORMATS[:p_long1] = "%d %b %Y %I:%M %P" # "25 Mar 2021 11:54 am" 
Time::DATE_FORMATS[:ps_long] = "%d %b %Y %I:%M:%S %P" # "25 Mar 2021 11:54:24 am" 
Time::DATE_FORMATS[:pd_long] = "%a, %d %b %Y %I:%M %P" # "Thu, 25 Mar 2021 11:54 am" 
Time::DATE_FORMATS[:pz_long] = "%d %b %Y %I:%M %P %z" # "25 Mar 2021 11:54 am +0530" 
Time::DATE_FORMATS[:pZ_long] = "%d %b %Y %I:%M %P %Z" # "25 Mar 2021 11:54 am IST" 
Time::DATE_FORMATS[:p_time] = "%I:%M %P" # 11:54 am  # :time  - 24 hours format
Time::DATE_FORMATS[:p_date] = "%d %b %Y" # 25 Mar 2021


# Others 
Date::DATE_FORMATS[:stamp] = "%Y%m%d" # YYYYMMDD
Time::DATE_FORMATS[:stamp] = "%Y%m%d%H%M%S" # YYYYMMDDHHMMSS


