# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
# set :output, "/path/to/my/cron_log.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end
#
# every 4.days do
#   runner "AnotherModel.prune_old_records"
# end

# Learn more: http://github.com/javan/whenever

set :output, {:error => nil}

#every 10.minutes do
#  runner "Order.delete_unprocessed_orders"
#end

#every 1.day do
#  runner "Address.purge_matched_duplicates"
#end

#every 1.day do
#  runner "FlexPassOrder.send_flex_pass_reminder"
#end

#every 5.minutes do
#  runner "OrderTask.run_pending"
#end

#every 1.day do
#  runner "SalesforceSync.sync_orders"
#end

#every 1.day do
#  runner "FlexPass.check_expirations"
#end

#every 4.hours do
#  runner "CalendarExchange.publish_calendar 'performance_schedule.ics'"
#end

