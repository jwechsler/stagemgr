class MembershipOrderMailingList < MailingList
  attr_reader :starting_date, :ending_date, :trg_lists

  def initialize(starting_date, ending_date, trg_lists, reporting_user_id = nil, theater_ids: [])
    super(reporting_user_id, theater_ids: theater_ids)
    @headers += %i[MembershipStartDate CurrentMember]
    @starting_date = starting_date
    @ending_date = ending_date
    @trg_lists = trg_lists
  end

  def create
    # Adjusted to correctly join with :address instead of :member
    orders = MembershipOrder.joins(:address)
                            .references(:address, membership_line_item: :membership)
                            .where('memberships.member_since >= ? AND memberships.member_since <= ? AND addresses.placeholder = ?',
                                   starting_date, ending_date, false)
                            .includes(:address, membership_line_item: :membership).distinct

    current_member_ids = Address.joins(:memberships).where(memberships: { status: Membership::ACTIVE }).distinct.pluck(:id)

    orders.each do |order|
      add_hash_to_data('MEM', order.address, order.membership.member_since, order.membership.membership_offer.name,
                       current_member_ids.include?(order.address.id), true)
    end

    file_name = "/tmp/membership_orders_#{starting_date.to_date.strftime('%y%m%d')}_#{ending_date.to_date.strftime('%y%m%d')}.csv"

    save_report_to_filestore(file_name)
  end

  private

  def add_hash_to_data(consolidation_code, address, membership_start_date, membership_name, current_member,
                       allow_email_export)
    season_tag = membership_start_date.year
    @processed_addresses[season_tag] = Set.new if @processed_addresses[season_tag].nil?
    return if @processed_addresses[season_tag].include?(address.id)

    hash = mailing_hash_from_buyer(address, allow_email_export)
    hash[:Email] = nil unless allow_email_export
    hash[:Title] = membership_name
    hash[:Season] = season_tag
    hash[:MembershipStartDate] = membership_start_date
    hash[:CurrentMember] = current_member
    data[consolidation_code] << hash
    if trg_lists
      membership_hash = hash.dup
      membership_hash[:Title] = 'All Members'
      data[consolidation_code] << membership_hash.dup
      membership_hash[:Season] = ''
      data[consolidation_code] << membership_hash
    end
    @processed_addresses[season_tag] << address.id
  end
end
