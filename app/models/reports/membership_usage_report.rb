class MembershipUsageReport < Report
  attr_reader :starting_date, :ending_date

  def initialize(starting_date, ending_date, reporting_user_id = nil)
    super(%i[Month Memberships Collected Paid], reporting_user_id)
    @starting_date = starting_date.to_date
    @ending_date = ending_date.to_date + 1.day
    @data = []
  end

  def create
    ActiveRecord::Base.connection.execute("SET sql_mode=(SELECT REPLACE(@@sql_mode, 'ONLY_FULL_GROUP_BY', ''));")

    paid_amount = MembershipPayment.where(
      'processed_on >= :start and processed_on < :end', start: starting_date, end: ending_date
    ).group("DATE_FORMAT(processed_on, '%Y-%m')").sum('amount')

    collected_amount = MembershipOrder.joins(:payments).where(
      'payments.processed_on >= :starting_date AND payments.processed_on < :ending_date',
      starting_date: starting_date, ending_date: ending_date
    ).group("DATE_FORMAT(payments.processed_on, '%Y-%m')").sum('payments.amount')

    distinct_membership_count = MembershipLineItem.joins(membership_order: :payments).where(
      'payments.processed_on >= :starting_date AND payments.processed_on < :ending_date',
      starting_date: starting_date, ending_date: ending_date
    ).distinct.group("DATE_FORMAT(payments.processed_on, '%Y-%m')").count('line_items.membership_id')

    ActiveRecord::Base.connection.execute("SET sql_mode=CONCAT(@@sql_mode, ',ONLY_FULL_GROUP_BY');")

    months = (paid_amount.keys + collected_amount.keys + distinct_membership_count.keys).uniq

    months.each do |month|
      paid = paid_amount[month] || 0
      collected = collected_amount[month] || 0
      membership_count = distinct_membership_count[month] || 0

      data << { Month: month, Memberships: membership_count, Collected: collected.to_money, Paid: paid.to_money }
    end
    unless reporting_user_id.nil?
      return report_data("/tmp/membership_usage_report_#{starting_date.to_date.strftime('%y%m%d')}_#{ending_date.to_date.strftime('%y%m%d')}.csv")
    end

    report_data
  end
end
