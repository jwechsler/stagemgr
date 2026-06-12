class DonationList < MailingList
  attr_reader :starting_date, :ending_date, :theater

  def initialize(starting_date, ending_date, theater_id, reporting_user_id = nil, theater_ids: [])
    super(reporting_user_id, theater_ids: theater_ids)
    @starting_date = starting_date
    @ending_date = ending_date
    @theater = Theater.find(theater_id)
    @headers += [:CloseDate, :Amount, :Processing, :Campaign]
  end

  def extract_donor_addresses(orders)
    order_set = orders.to_set
    order_address_set = orders.map { |o| o.address }.to_set

    order_set.each do |order|
      consolidation_code = 'DON'
      season_tag = order.created_at.year
      address = order.address
      hash = self.mailing_hash_from_buyer(address, true)
      hash[:Title] = 'All Donors'
      hash[:Season] = season_tag
      hash[:CloseDate] = order.created_at.to_date
      hash[:Amount] = order.total_paid
      hash[:Campaign] = order.campaign
      hash[:Processing] = order.processing_fee
      self.data[consolidation_code] << hash
    end
  end

  def create
    orders = DonationOrder.finalized.joins(:address).references(:address).where(
      '(CAST(orders.created_at AS DATE) between :start_date and :end_date) and orders.theater_id = :theater_id and (addresses.placeholder is null OR addresses.placeholder <> :is_pl)',
      start_date: self.starting_date.to_date, end_date: self.ending_date.to_date,
      is_pl: true, theater_id: self.theater.id
    ).includes(:address, :payments)
    Rails.logger.debug("Pulled #{orders.count} orders for DonationList")
    self.extract_donor_addresses(orders)

    file_name = "/tmp/donors_#{self.starting_date.to_date.strftime('%y%m%d')}_#{self.ending_date.to_date.strftime('%y%m%d')}.csv"
    self.save_report_to_filestore(file_name)
  end
end
