# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
# set :output, "/path/to/my/cron_log.log"
#

# every :day, at: '01:00 AM' do
#   runner "Inventory.generate_and_send_inward_visibility_report"
# end

# every :day, at: '01:00 PM' do
#   runner "Inventory.generate_and_send_inward_visibility_report"
# end

# every :day, at: '01:30 PM' do
#   runner "Inventory.generate_and_send_monthly_report_daily('outward')"
#   runner "Inventory.generate_and_send_monthly_report_daily('inward')"
# end

# every :day, at: '12:30 AM' do
#   runner "Inventory.generate_and_send_monthly_report_daily('outward')"
#   runner "Inventory.generate_and_send_monthly_report_daily('inward')"
# end


# every :day, at: '12:30 PM' do
#   runner "LiquidationOrder.generate_daily_dispatch_lots"
# end

#every :day, at: '08:30 AM' do
#  runner "LiquidationOrder.generate_daily_dispatch_lots"
#end

# every 15.minutes do
#   runner "LiquidationOrder.auto_assign_bid"
# end

# every 15.minutes do
#   runner "InventoryInformation.create_inventory_histories"
#   runner "LiquidationOrder.auto_assign_bid"
# end
# every :day, at: '09:00 PM' do
#   runner "AlertConfiguration.check_for_bucket_records"
# end

# every 1.minutes do
#   runner "Inventory.push_obd_gr"
#   runner "Inventory.push_ibd_gr"
#   runner "Inventory.push_gi_gr"
# end

# every 1.month, at: 'start of the month at 12:30 am' do
#   runner "Inventory.generate_and_send_yearly_report('outward')"
#   runner "Inventory.generate_and_send_yearly_report('inward')"
# end

#
# every 4.days do
#   runner "AnotherModel.prune_old_records"
# end

# Learn more: http://github.com/javan/whenever


# every 12.hours do
#   runner "LiquidationOrder.move_dispatch_lot"
#   runner "VendorReturn.move_dispatch_lot"
# end

# every 15.minutes do
#  runner "LiquidationOrder.auto_publish_lots"
# end

