namespace :outreach do
  desc 'Backfill reminder/followup OutreachTasks missed while task creation was ' \
       'disconnected (commit 517b2511, 2024-09 through 2026-08). Idempotent. ' \
       'Set DRY_RUN=1 to report counts without creating tasks.'
  task backfill: :environment do
    dry_run = ENV['DRY_RUN'].present?
    reminder_count = 0
    followup_count = 0

    scope = TicketOrder.includes(performance: :production)
                       .joins(:performance)
                       .where(status: [Order::PROCESSED, Order::FULFILLED])
                       .where(performances: { performance_date: Date.current.. })

    scope.find_each do |order|
      performance = order.performance
      next if performance.nil? || performance.suppress_notification || !order.contains_tickets?

      # mirrors the timing rule in TicketOrder#create_reminder_task: only
      # shows at least two days out get a reminder
      if performance.performance_date.to_datetime - 2.days >= Time.now &&
         !OutreachTask.exists?(order_id: order.id, method_symbol: 'performance_reminder')
        reminder_count += 1
        order.send(:create_reminder_task) unless dry_run
      end

      if order.status == Order::FULFILLED &&
         performance.production.use_ticket_email_templates? &&
         !OutreachTask.where(order_id: order.id).where("method_symbol LIKE '%followup'").exists?
        followup_count += 1
        order.send(:create_performance_followup_task) unless dry_run
      end
    end

    verb = dry_run ? 'Would create' : 'Created'
    puts "#{verb} #{reminder_count} performance reminder(s) and #{followup_count} followup(s)."
  end
end
