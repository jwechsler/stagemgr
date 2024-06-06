require 'street_address'
require 'csv'
require 'people'

class Address < ApplicationRecord

  # audited only:[:first_name, :last_name, :line1, :line2, :email, :city, :state, :zipcode, :phone], max_audits: 30

  validates_presence_of :full_name
  validates :email, :email=>true, :allow_blank=>true
  before_validation :regularize!, :if=>:changed?
  has_many :orders, inverse_of: :address
  has_many :orders_as_recipient, :class_name=>:order, :foreign_key=>:recipient_address_id, inverse_of: :recipient_address
  has_many :address_tags, inverse_of: :address
  has_many :memberships, inverse_of: :address
  has_many :flex_passes, inverse_of: :address
  has_and_belongs_to_many :productions

  accepts_nested_attributes_for :address_tags, :reject_if => proc { |attributes| attributes['tag_label'].blank? }, :allow_destroy => true
  before_save :set_search_name
  before_save :purge_duplicate_tags
  before_destroy :ensure_no_finalized_orders

  MAILLIST_STATUS = (
    REQUESTED, SAVED =
  "Requested", "Saved")

  SEARCHABLE_REGEXP = /[\d+\s+\.!,]/

  def self.parse_name(full_name)
    unless full_name.blank?
      parsed = People::NameParser.new(:couples=>true).parse(full_name)
      cleaned_name = parsed[:clean]
      if parsed[:parsed]
        f_name = parsed[:first]
        f_name2 = parsed[:first2]
        l_name = parsed[:last]
        m_name = parsed[:middle]
      else
        f_name = ""
        l_name = parsed[:clean]
        m_name = ""
      end
      [cleaned_name, f_name, m_name, l_name, f_name2]
    else
      ["","","","",""]
    end
  end

  def parse_full_name
    cleaned_name, f_name, m_name, l_name, f_name2 = Address.parse_name(self.full_name)
    self.full_name = cleaned_name
    [f_name, m_name, l_name]
  end

  def set_full_name(full_name, first_name = nil, middle_name = nil, last_name = nil)
    if full_name.blank? then
      self.full_name = ""
      self.full_name = first_name unless first_name.blank?
      self.full_name += self.full_name.blank? ? " #{middle_name}" : middle_name unless middle_name.blank?
      self.full_name += self.full_name.blank? ? last_name : " #{last_name}"  unless last_name.blank?
    else
      self.full_name = full_name
    end
  end

  def regularize!

    self.first_name, self.middle_name, self.last_name = parse_full_name

    self.email.strip! unless self.email.nil?
    self.line1.strip! unless self.line1.nil?
    self.city = self.city.titlecase.strip unless self.city.nil?
    self.line2.strip! unless self.line2.nil?
    if (!self.line1.nil? || !self.line2.nil?) then
      parsed_address = StreetAddress::US.parse_address("#{self.line1}\n#{self.line2}")
      if !parsed_address.nil? then
        self.street_number = parsed_address.number
        self.street = parsed_address.street
        self.street_type = parsed_address.street_type
        self.unit = parsed_address.unit
        self.unit_prefix = parsed_address.unit_prefix
      end
    else
      self.street_number = nil
      self.street = nil
      self.street_type = nil
      self.unit = nil
      self.unit_prefix = nil
    end
    self.email.downcase! unless self.email.nil?
    self.street_number.upcase! unless self.street_number.nil?
    self.street.upcase! unless self.street.nil?
    self.street_type.upcase! unless self.street_type.nil?
    self.unit_prefix.upcase! unless self.unit_prefix.nil?
    self.search_name = name_as_searchable

    self
  end

  def find_original
    self.regularize!
    comparison_id = self.id.nil? ? -1 : self.id

    matches = Address.where("search_name = :search_name and (email = :email #{(self.email.blank? && self.street_number.blank?) ? '' : ' or email is null or email = \'\''}) and id <> :id", {:search_name=>name_as_searchable, :id=>comparison_id, :email => (self.email.blank? ? '' : self.email.strip)})
    if matches.nil? || matches.size == 0
      matches = Address.where("first_name = :first_name and last_name = :last_name and (email = :email #{(self.email.blank? && self.street_number.blank?) ? '' : ' or email is null or email = \'\''}) and id <> :id", {:first_name => self.first_name, :last_name => self.last_name, :id=>comparison_id, :email => (self.email.blank? ? '' : self.email.strip)})
      if matches.nil? || matches.size == 0
        matches = Address.where("id <> :id AND street_number = :street_number AND street = :street AND city = :city and search_name = :search_name #{self.email.blank? ? '' : 'and (email = \'\' or email is null)'}",
                                {:id=>comparison_id, :street_number=>self.street_number, :street=>self.street,
                                 :city=>self.city, :search_name=>name_as_searchable})
        if matches.nil? || matches.size == 0
          matches = Address.where("id <> :id and search_name = :search_name and street_number is null and street is null and city is null and (email = '' or email is null)",
                                  {:id=>comparison_id, :search_name=>name_as_searchable})
        end
      end
    end
    return matches.nil? ? nil : matches.select { |a| self.id.nil? ? true : (a.id < self.id) }.sort! { |a, b| a.id <=> b.id }.first

  end

  def customer?
    !self.placeholder?
  end

  def ensure_no_finalized_orders
    raise "Cannot delete an address with finalized orders" unless orders.reload.select{|o| o.finalized? }.count == 0
  end

  def update_from(newer)
    self.email = newer.email unless newer.email.blank?
    self.first_name = newer.first_name unless newer.email.blank?
    self.last_name = newer.last_name unless newer.last_name.blank?
    self.full_name = newer.full_name unless newer.full_name.blank?
    self.line1 = newer.line1 unless newer.line1.blank?
    self.line2 = newer.line2 unless newer.line2.blank?
    self.city = newer.city unless newer.city.blank?
    self.state = newer.state unless newer.state.blank?
    self.zipcode = newer.zipcode unless newer.zipcode.blank?
    self.phone = newer.phone unless newer.phone.blank?
    self.vip ||= newer.vip?
    self.placeholder ||= newer.placeholder?
    if self.donor_tier_updated_on.nil? || (self.donor_tier_updated_on < newer.donor_tier_updated_on)
      self.donor_tier_for_last_fiscal_year = newer.donor_tier_for_last_fiscal_year
      self.donor_tier_for_current_fiscal_year = newer.donor_tier_for_current_fiscal_year
    end
    newer.address_tags.each do |tag|
      existing_tag = self.address_tags.select { |t|
        (t.tag_label == tag.tag_label) && (t.theater_id == tag.theater_id) }.first
      if existing_tag.nil?
        self.address_tags << tag
      else
        existing_tag.tag_value = tag.tag_value
        existing_tag.theater = tag.theater
      end
    end
  end

  def merge_and_purge(from_address)
    Rails.logger.debug("Merging address \##{from_address.id} into \##{self.id}")
    Address.transaction do
      self.update_from(from_address)
      self.orders << from_address.orders
      self.memberships << from_address.memberships
      self.flex_passes << from_address.flex_passes
      self.productions << from_address.productions
      self.save!
      from_address.reload
      from_address.destroy
    end
  end


  def self.purge_matched_duplicates
    Address.transaction do
      candidates = Address.where("not exists (select id from orders where orders.address_id = addresses.id)")
      candidates.each { |a| a.destroy unless a.find_original.nil? }
    end
  end

  def self.update_address_from_csv(csv_file)
    header_required = true
    last_id = -1
    index = Hash.new
    CSV.foreach(csv_file) do |row|
      if header_required
        header_required = false
        index = {
          :address_id => row.index("Client Patron ID"),
          :full_name => row.index("Full Name"),
          :line1 => row.index("Address 1"),
          :line2 => row.index("Address 2"),
          :city => row.index("City"),
          :state => row.index("State"),
          :prefix => row.index("Prefix"),
          :zipcode => row.index("Zip"),
          :zip4 => row.index("Zip4")
        }
      else
        new_id = row[index[:address_id]].to_i
        case
        when new_id < last_id
          raise "Import file must be sorted by Client Patron ID for effective purging"
        when new_id > last_id
          begin
            new_address = Address.find(new_id)
            new_address.full_name = row[index[:full_name]]
            new_address.line1 = row[index[:line1]]
            new_address.line2 = row[index[:line2]]
            new_address.city = row[index[:city]]
            new_address.state = row[index[:state]]
            new_address.prefix = row[index[:prefix]]
            zip = row[index[:zipcode]]
            zip = zip + '-' + row[index[:zip4]] unless row[index[:zip4]].blank?
            new_address.zipcode = zip
            original = new_address.find_original
            if original.nil?
              Rails.logger.info("Updating info on address ##{new_address.id}")
              new_address.save!
            else
              Rails.logger.info("Merge/Purge on address ##{new_address.id} into ##{original.id}")
              original.merge_and_purge(new_address)
            end
          rescue ActiveRecord::RecordNotFound => e
            Rails.logger.info("Could not locate address ##{new_id}")
          end
        end
        last_id = new_id
      end

    end
  end


  def field_changed_after?(field_name, change_time)
    unless change_time.nil?
      self.audits.select { |audit| audit.created_at > change_time unless audit.created_at.nil? }.each do |revision|
        revision.audited_changes.each do |fld, changes|
          return true if fld == field_name.to_s
        end
      end
      return false
    else
      return true
    end
  end

  def customer_tag(order = nil)
    attendance_code = self.revenue_collected(18.months.ago).truncate.to_s.reverse.rjust(4, '0')
    attendance_code += self.performances_attended(18.months.ago).size.to_s.reverse.rjust(2, '0')
    attendance_code += "A" if self.is_donor?
    attendance_code += "M" if self.is_current_member?
    attendance_code

  end

  def is_current_member?
    MembershipLineItem.joins(:order,:membership).references(:order, :membership).where("orders.address_id = :address_id AND memberships.status = :active", address_id:self.id, active: Membership::ACTIVE).size > 0
  end

  def active_memberships
    self.orders.select { |o| (o.is_a? MembershipOrder) && !o.membership.nil? && (o.membership.status == Membership::ACTIVE) }.map{|o| o.membership}
  end

  def current_membership
    self.active_memberships.first
  end

  def has_finalized_orders?
    self.orders.select { |o| o.finalized? }.size > 0
  end

  def self.export_addresses_as_csv(addresses, filename)
    csv_string = FasterCSV.generate do |csv|
      csv << [:id, :first_name, :last_name, :street_number, :street, :street_type, :unit, :unit_prefix, :zipcode, :customer_tag]

      addresses.each do |r|
        csv << [r.id, r.first_name, r.last_name, r.street_number, r.street, r.street_type, r.unit, r.unit_prefix, r.zipcode, r.customer_tag]
      end
    end
    File.open(filename, "w") do |the_file|
      the_file.puts csv_string
    end
  end

  def contactable?
    !self.line1.blank? || !self.email.blank?
  end

  def current_member?
    self.is_current_member?
  end

  def is_current_flex_pass_holder?
    self.orders.select { |o| (o.is_a? FlexPassOrder) && (o.flex_pass_line_item.flex_pass.available?) }.count > 0
  end

  def has_flex_pass?
    FlexPassLineItem.joins(:order, :flex_passes).references(:order, :flex_passes).where("orders.address_id = :address_id AND flex_passes.active = :active", address_id:self.id, active: true).size > 0
  end

  # @todo Flex pass programs can't be hard coded.
  def flex_pass_candidate?
    if !has_flex_pass?
      recent_orders = self.orders.select { |o| o.created_at > 1.year.ago }
      total_spent = recent_orders.sum { |o| o.total_paid }
      num_paid_tickets = recent_orders.sum { |o| o.total_paid > 0 ? o.number_of_tickets : 0 }
      candidate = recent_orders.size > 2 && total_spent/num_paid_tickets > 20
    else
      candidate = false
    end
    candidate
  end

  def first_time_paying? (current_order)
    self.orders.select { |o| (o.id != current_order.id) && o.settled? }.size ==0
  end

  def revenue_collected(since_when = 18.months.ago)
    Payment.includes(:order).where('orders.status in (?) and payments.processed_on >= ?', Order::SETTLED_STATUSES, since_when).sum(:amount)
  end

  def performances_attended(since_when = 5.years.ago)
    TicketOrder.includes(:performance).joins(:performance).where("orders.address_id = ? and orders.status = ? and performances.performance_date >= ? and performances.performance_date <= ?",
                                    self.id, Order::FULFILLED, since_when, Date.today)
  end

  def orders_processed(for_theaters = nil)
    if for_theaters.nil?
      TicketOrder.attending.where("orders.address_id = ?",
                                       self.id).count
    else
      TicketOrder.attending.where("orders.address_id = ? and orders.performance_id in (select id from performances where production_id in (select id from productions where theater_id in (?)))",
                      self.id, for_theaters).count
    end
  end

  def is_donor?
    return self.donated_this_year? || self.donated_last_year?
  end

  def most_recent_donation_tier
    return donor_tier_for_current_fiscal_year || donor_tier_for_last_fiscal_year
  end

  def donated_year
    self.donor_tier_updated_on.year
  end

  def donated_this_year?
    return !self.donor_tier_updated_on.nil? && ((self.donor_tier_updated_on.year == Date.today.year && !self.donor_tier_for_current_fiscal_year.nil?))
  end

  def donated_last_year?
    if !self.donor_tier_updated_on.nil?
      return true if (self.donor_tier_updated_on.year == Date.today.year-1 && !self.donor_tier_for_current_fiscal_year.nil?)
      return true if (self.donor_tier_updated_on.year = Date.today.year && !self.donor_tier_for_previous_fiscal_year.nil?)
    end
    return false
  end

  def to_s
    "#{self.full_name} <#{self.email}>"
  end

  def last_attendance_date
    TicketOrder.joins(:performance).maximum('performance_date',:conditions=>["orders.address_id = ?", self.id])
  end

  def productions_attended(start_date = 25.years.ago.to_date, end_date = Date.today)
    Production.joins(:performances=>:orders).references(:orders).where("orders.address_id = :address_id and orders.status in (:attended_status) and performances.performance_date between :start_date AND :end_date",
      address_id: self.id,
      start_date: start_date,
      end_date: end_date,
      attended_status: Order::ATTENDING_STATUSES).distinct
  end

  def theaters_attended(start_date = 25.years.ago.to_date, end_date = Date.today)
    Theater.joins(:productions=>[:performances=>:orders]).references(:orders).where("orders.address_id = :address_id and orders.status in (:attended_status) and performances.performance_date between :start_date AND :end_date",
      address_id: self.id,
      start_date: start_date,
      end_date: end_date,
      attended_status: Order::ATTENDING_STATUSES).distinct
  end

  def number_of_productions_attended(start_date = 25.years.ago.to_date, end_date = Date.today)
    self.productions_attended(start_date, end_date).size
  end

  def names_of_productions_attended(start_date = 25.years.ago.to_date, end_date =  Date.today)
    self.productions_attended(start_date,end_date).pluck(:name)
  end

  def number_of_theaters_attended(start_date = 25.years.ago.to_date, end_date =  Date.today)
    self.theaters_attended(start_date, end_date).size
  end

  def names_of_theaters_attended(start_date = 25.years.ago.to_date, end_date =  Date.today)
    self.theaters_attended(start_date,end_date).pluck(:name)
  end


  def external_id(theater_ids)
    found = address_tags.select{|tag| theater_ids.include?(tag.theater_id) && tag.tag_label.eql?(AddressTag::EXTERNAL_ID) }
    if found.empty?
      return ""
    else
      return found[0].tag_value
    end
  end

  def purge_duplicate_tags
    unique_tags = self.address_tags.map{|a| {tag_label: a.tag_label, tag_value: a.tag_value, theater_id: a.theater_id} }.uniq
    unique_tags.each do |tag|
      save_me = true
      self.address_tags.each do |address_tag|
        if {tag_label: address_tag.tag_label, tag_value: address_tag.tag_value, theater_id: address_tag.theater_id}.eql?(tag)
          self.address_tags.delete(AddressTag.find(address_tag.id)) unless save_me
          save_me = false
        end
      end

    end

  end

  def self.unattached

  end

  def self.delete_unattached
    unassociated = Address.where("addresses.id not in (select address_id from orders union select address_id from addresses_productions)")
    unassociated.each do |address|
      if !address.vip? && !address.placeholder? && address.address_tags.empty? && address.updated_at < Time.now - 1.week
        address.destroy
      end
    end
  end

  protected
  def set_search_name
    self.search_name = self.full_name.gsub(/[\d+\s+\.!,]/,'').upcase
    self.last_first_name = "#{self.last_name}#{self.first_name}#{self.middle_name}".gsub(/[\d+\s+\.!,]/,'').upcase
  end

  private
  def name_as_searchable
    full_name.gsub(SEARCHABLE_REGEXP,'').upcase
  end

end

#MyEmma code

class Address
  def self.sync_ids_to_my_emma
    members = MyEmma::Member.all
    members.each {|m|
      unless (m.email.blank?)
        a = Address.find_by(email: m.email)
        unless (a.nil? || a.email.blank? || (m.remoteid.eql?(a.id.to_s)))
          m.remoteid = a.id.to_s
          m.save
        end
      end
    }
  end
end


