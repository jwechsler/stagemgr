class FlexPassUsageReport < Report

  attr_reader :starting_date, :ending_date

  def initialize(starting_date, ending_date, reporting_user_id = nil)
    super([:month, :new_passes ,:new_deposits,:tickets_paid_out,:total_spiff,
            :total_flat_payout,:total_facility,:expired_flex_passes,
            :recovered_amount,:total_due_to_facility], reporting_user_id)
    @starting_date = starting_date
    @ending_date = ending_date
    @data = Array.new
  end

  def create
    ActiveRecord::Base.connection.execute("SET sql_mode=(SELECT REPLACE(@@sql_mode, 'ONLY_FULL_GROUP_BY', ''));")
  
    paid_amount = FlexPassPayment.where(
      'processed_on >= :start and processed_on <= :end', start: starting_date, end: ending_date
    ).select("DATE_FORMAT(processed_on, '%Y-%m'), amount").group(
      "DATE_FORMAT(processed_on, '%Y-%m')"
    ).reorder(:processed_on).sum('amount')
  
    paid_amount.each{|key, value| paid_amount[key] = {tickets_paid_out: value} }  

    collected_amounts = FlexPassOrder.joins(flex_pass_line_item: { flex_pass: :flex_pass_offer })
                                 .joins(:payments)
                                 .where('payments.processed_on >= :starting_date AND payments.processed_on <= :ending_date',
                                        starting_date: starting_date, ending_date: ending_date)
                                 .group("DATE_FORMAT(payments.processed_on, '%Y-%m')")
                                 .select(
                                   "DATE_FORMAT(payments.processed_on, '%Y-%m') as processed_month",
                                   "COUNT(*) as new_passes",
                                   "SUM(payments.amount) as new_deposits",
                                   "SUM(flex_pass_offers.price) as total_price",
                                   "SUM(flex_pass_offers.spiff) as total_spiff",
                                   "SUM(flex_pass_offers.flat_payout) as total_flat_payout",
                                   "SUM(flex_pass_offers.facility_fee) as total_facility"
                                 )

    recovered_amounts = FlexPass.joins(:flex_pass_payments)
          .joins(:flex_pass_offer)
          .where("expiration_date >= :starting_date AND expiration_date <= :ending_date", starting_date: starting_date, ending_date: ending_date)
          .group("DATE_FORMAT(expiration_date, '%Y-%m')")
          .select(
             "DATE_FORMAT(expiration_date, '%Y-%m') as processed_month",
             "COUNT(*) as expired_flex_passes",
            "(SUM(flex_pass_offers.price)-sum(flex_pass_offers.facility_fee)-sum(flex_pass_offers.flat_payout) - SUM(amount)) as recovered_amount"
          )

   
    recovered_amounts_hash = recovered_amounts.map { |record|
      [record.processed_month, {recovered_amount: record.recovered_amount, 
        expired_flex_passes: record.expired_flex_passes}]
    }.to_h

    collected_amounts_hash = collected_amounts.map { |record| 
      [record.processed_month, {
        new_passes: record.new_passes,
        new_deposits: record.new_deposits,
        total_spiff: record.total_spiff,
        total_flat_payout: record.total_flat_payout,
        total_facility: record.total_facility,
        
      }]
    }.to_h

    months = (paid_amount.keys + recovered_amounts_hash.keys + collected_amounts_hash.keys).uniq.sort

    months.each do |month|
      
      merged_hash = (paid_amount[month] || Hash.new).merge(recovered_amounts_hash[month] || {}).merge(collected_amounts_hash[month] || {})
      
      self.data << {month: month, 
        new_passes:             (merged_hash[:new_passes] || 0),
        new_deposits:           (merged_hash[:new_deposits] || 0.0).to_money,
        tickets_paid_out:       (merged_hash[:tickets_paid_out] || 0.0).to_money,
        total_spiff:            (merged_hash[:total_spiff]|| 0.0).to_money,
        total_flat_payout:      (merged_hash[:total_flat_payout] || 0.0).to_money,
        total_facility:         (merged_hash[:total_facility] || 0.0).to_money,
        expired_flex_passes:    (merged_hash[:expired_flex_passes] || 0),
        recovered_amount:       (merged_hash[:recovered_amount] || 0.0).to_money,
        total_due_to_facility:  ((merged_hash[:total_spiff] || 0.0) + (merged_hash[:total_facility] || 0.0)+(merged_hash[:recovered_amount] || 0.0)).to_money
      }

    end
    return self.report_data("/tmp/flex_pass_usage_report_#{self.starting_date.to_date.strftime('%y%m%d')}_#{self.ending_date.to_date.strftime('%y%m%d')}.csv")
  end

end