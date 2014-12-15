class ProductionMailingList < MailingList

  attr_accessor :production, :allow_email_exports

  def initialize(production, reporting_user_id = nil, allow_email_exports = false)
    super(reporting_user_id)
    @production = production
    @allow_email_exports = allow_email_exports
  end

  def allow_email_exports?
    allow_email_exports == true
  end

  def create
    season_tag = self.production.season.to_i + 1
    all_attendees = self.production.attendees
    orders = TicketOrder.includes(:address, :payments, :theater, {:performance=>:production}).where('performances.production_id = ?', self.production.id)
    members_by_email = self.production.attendees_on_email_list
    order_set = orders.to_set

    consolidation_code = self.production.theater.is_default? ? 'ALL' : 'REN'
    all_attendees.each do |address|
      hash = MailingList.mailing_hash_from_buyer(address)
      unless hash[:Email].nil?
        unless self.allow_email_exports? || members_by_email.has_key?(hash[:Email].downcase)
          hash[:Email] = nil
        end
      end
      hash[:Title] = self.production.name
      hash[:Season] = season_tag
      address_orders = order_set & address.orders
      buyer_type = case
      when address_orders.size == 0
        nil
      when address_orders.select{|o| o.paid_with_membership?}.size > 0
        'MEM'
      when address_orders.inject(0) { |t,o| t + o.total}  == 0
        'CMP'
      else
        'STB'
      end
      self.data[consolidation_code] << hash
      self.data[buyer_type] << hash unless buyer_type.nil?
    end

    members_by_email.each do |member_record|
      hash = MailingList.trg_hash_from_myemma(member_record[1])
      hash[:Title] = self.production.name
      hash[:Season] = season_tag
      self.data['EMA'] << hash
    end

    file_name = "/tmp/#{Admin::ReportsHelper.safe_title(self.production.name)}.csv"
    self.save_report_to_filestore(file_name)

  end
end
