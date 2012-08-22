require 'street_address'
require 'address_imports'
require 'csv'
require 'name_parse'

class Address < ActiveRecord::Base

  include AddressImports

  validates_presence_of :full_name
  validates :email, :email=>true
  before_validation :regularize!
  has_many :orders
  has_many :address_tags
  has_many :memberships
  accepts_nested_attributes_for :address_tags, :allow_destroy => true

  MAILLIST_STATUS = (
    REQUESTED, SAVED =
  "Requested", "Saved")

  attr_accessible :full_name, :line1, :line2, :city, :state, :zipcode, :email, :phone, :street_number, :address_tags_attributes
  acts_as_audited :protect=>false, :except=>['street_number', 'street', 'street_type', 'unit', 'unit_prefix', 'search_name']
  attr_accessor :sf_object

  def parse_full_name
    self.full_name = NameCase(self.full_name)
    if self.full_name.include?(' ')
      parsed = NameParse::Parser.new(self.full_name)
      if [:first_last, :first_mid_last].include?(parsed.matched)
        f_name = parsed.first
        l_name = parsed.last
        m_name = parsed.middle
      else
        brute_force = self.full_name.split(' ')
        l_name = brute_force.last
        f_name = brute_force[0..-2].join(' ')
      end
    else
      l_name = self.full_name
      f_name = ''
      m_name = ''
    end
    [f_name, m_name, l_name]
  end

  def regularize!
    if self.changed?
      self.first_name, self.middle_name, self.last_name = self.parse_full_name

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
    end

    self
  end

  def find_original
    self.regularize!
    comparison_id = self.id.nil? ? -1 : self.id

    matches = Address.where("search_name = :search_name and (email = :email #{(self.email.blank? && self.street_number.blank?) ? '' : ' or email is null or email = \'\''}) and id <> :id", {:search_name=>name_as_searchable, :id=>comparison_id, :email => (self.email.blank? ? '' : self.email.strip)})
    if matches.nil? || matches.size == 0
      matches = Address.where("id <> :id AND street_number = :street_number AND street = :street AND city = :city and search_name = :search_name #{self.email.blank? ? '' : 'and (email = \'\' or email is null)'}",
                              {:id=>comparison_id, :street_number=>self.street_number, :street=>self.street,
                               :city=>self.city, :search_name=>name_as_searchable})
      if matches.nil? || matches.size == 0
        matches = Address.where("id <> :id and search_name = :search_name and street_number is null and street is null and city is null and (email = '' or email is null)",
                                {:id=>comparison_id, :search_name=>name_as_searchable})
      end
    end
    return matches.nil? ? nil : matches.select { |a| self.id.nil? ? true : (a.id < self.id) }.sort! { |a, b| a.id <=> b.id }.first

  end

  def update_from(newer)
    self.email = newer.email unless newer.email.blank?
    self.first_name = newer.first_name unless newer.email.blank?
    self.last_name = newer.last_name unless newer.last_name.blank?
    self.line1 = newer.line1 unless newer.line1.blank?
    self.line2 = newer.line2 unless newer.line2.blank?
    self.city = newer.city unless newer.city.blank?
    self.state = newer.state unless newer.state.blank?
    self.zipcode = newer.zipcode unless newer.zipcode.blank?
    self.phone = newer.phone unless newer.phone.blank?

    newer.address_tags.each do |tag|
      existing_tag = self.address_tags.select { |t| (t.tag_label == tag.tag_label) && (t.theater_id == tag.theater_id) }.first
      if existing_tag.nil?
        self.address_tags << tag
      else
        existing_tag.tag_value = tag.tag_value
        existing_tag.theater = tag.theater
      end
    end
  end

  def self.purge_matched_duplicates
    Address.transaction do
      candidates = Address.where("not exists (select id from orders where orders.address_id = addresses.id)")
      candidates.each { |a| a.destroy unless a.find_original.nil? }
    end
  end

  def sync_to_salesforce!
    if self.sf_last_sync_at.nil? || (self.sf_last_sync_at < self.updated_at)
      sf_contact = SalesforceData::Contact.find_by_stagemgr_id__c("#{self.id}")
      sync_time = DateTime.now
      puts "syncing address id ##{self.id}"
      if sf_contact.nil?
        sf_contact = create_salesforce_contact
      else
        if self.field_changed_after?(:first_name, self.sf_last_sync_at)
          sf_contact.FirstName = self.first_name unless self.first_name.blank?
        else
          self.first_name = sf_contact.FirstName unless sf_contact.FirstName.blank?
        end
        if self.field_changed_after?(:last_name, self.sf_last_sync_at)
          sf_contact.LastName = self.last_name unless self.last_name.blank?
        else
          self.last_name = sf_contact.LastName unless sf_contact.LastName.blank?
        end

        if self.field_changed_after?(:email, self.sf_last_sync_at)
          sf_contact.Email = self.email unless self.email.blank?
        else
          self.email = sf_contact.Email unless sf_contact.Email.blank?
        end

        if [:line1, :line2].select { |f| self.field_changed_after?(f, self.sf_last_sync_at) }.size > 0
          sf_contact.MailingStreet="#{self.line1}\r\n#{self.line2}" unless self.line1.blank?
        else
          unless sf_contact.MailingStreet.blank?
            lines = sf_contact.MailingStreet.split("\r\n")
            if lines.size > 0
              self.line1 = lines[0]
              if lines.size > 1
                self.line2 = lines[1]
              end
            end
          end
        end

        if self.field_changed_after?(:city, self.sf_last_sync_at)
          sf_contact.MailingCity = self.city unless self.city.blank?
        else
          self.city = sf_contact.MailingCity unless sf_contact.MailingCity.blank?
        end

        if self.field_changed_after?(:state, self.sf_last_sync_at)
          sf_contact.MailingState = self.state unless self.state.blank?
        else
          self.state = sf_contact.MailingState unless sf_contact.MailingCity.blank?
        end

        if self.field_changed_after?(:zipcode, self.sf_last_sync_at)
          sf_contact.MailingPostalCode = self.zipcode unless self.zipcode.blank?
        else
          self.zipcode = sf_contact.MailingPostalCode unless sf_contact.MailingPostalCode.blank?
        end

        if self.field_changed_after?(:phone, self.sf_last_sync_at)
          sf_contact.Phone = self.phone unless self.phone.blank?
        else
          self.phone = sf_contact.Phone unless sf_contact.Phone.blank?
        end
        sf_contact.stagemgr_last_sync_at__c = sync_time
        puts "  saving address #{self.id} to salesforce"
        sf_contact.save
      end
      self.sf_last_sync_at = DateTime.now + 15.seconds
      self.save!
      self.sf_object = sf_contact
    end
  end

  def sf
    if self.sf_object.nil?
      self.sf_last_sync_at=nil
      self.sync_to_salesforce!
    end
    self.sf_object
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
    attendance_code += self.performances_attended(18.months.ago).to_s.reverse.rjust(2, '0')
    attendance_code += "A" if self.is_donor?
    attendance_code += "M" if self.is_current_member?
    attendance_code

  end

  def is_current_member?
    self.orders.select { |o| (o.is_a? MembershipOrder) && (o.membership_line_items.first.membership.status == Membership::ACTIVE) }.count > 0
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
    self.orders.select { |o| (o.is_a? FlexPassOrder) && (o.flex_pass_line_items.first.flex_pass.active?) }.count > 0
  end

  def has_flex_pass?
    !FlexPass.find_by_address_id(self.id).nil?
  end

  # @todo Flex pass programs can't be hard coded.
  def flex_pass_candidate?
    if !has_flex_pass?

      recent_orders = self.orders.select { |o| o.created_at > 1.year.ago }
      total_spent = recent_orders.sum { |o| o.total }
      num_paid_tickets = recent_orders.sum { |o| o.total > 0 ? o.ticket_quantity : 0 }
      candidate = recent_orders.size > 2 && total_spent/num_paid_tickets > 20
    else
      candidate = false
    end
    candidate
  end

  def first_time_paying? (current_order)
    self.orders.select { |o| (o.id != current_order.id) && o.paid? }.size ==0
  end


  def self.import_timeline_csv(filepath)
    num_read = 0
    num_merged = 0
    timeline = Theater.find_by_name('TimeLine Theatre Company')
    FasterCSV.foreach(filepath) do |row|
      a=Address.new
      a.first_name = row[1]
      a.last_name = row[2]
      a.line1 = row[3]
      a.line2 = row[4]
      a.city = row[5]
      a.state = row[6]
      a.zipcode = row[7]
      a.phone = row[10]
      a.phone = row[8] if a.phone.blank?
      a.phone = row[9] if a.phone.blank?

      a.email = row[11]
      a.regularize!
      sub_tag = AddressTag.new
      sub_tag.address = a
      sub_tag.tag_label = 'Subscriber ID'
      sub_tag.tag_value = row[0]
      sub_tag.theater_id = timeline.id
      a.address_tags << sub_tag
      type_tag = AddressTag.new
      type_tag.address = a
      type_tag.tag_label = 'Subscriber Type'
      type_tag.tag_value = row[13]
      type_tag.theater_id = timeline.id
      a.address_tags << type_tag
      existing = a.find_original
      if !existing.nil?
        num_merged += 1
        existing.update_from(a)
        a = existing
      end
      num_read += 1
      a.save!
    end
    puts "CSV Import Successful,  #{num_read} records loaded, #{num_merged} merged"
  end

  def revenue_collected(since_when = 18.months.ago)
    self.orders.select { |o| o.paid? && Payment.maximum(:processed_on, :conditions=>["order_id = ?", o.id]) > since_when.to_date }.map { |o| o.total }.sum
  end

  def performances_attended(since_when = 5.years.ago)
    TicketOrder.count(:include=>[:performance],
                      :conditions=>["orders.address_id = ? and orders.status = ? and performances.performance_date >= ? and performances.performance_date <= ?",
                                    self.id, Order::FULFILLED, since_when, Date.today])
  end

  def orders_processed(for_theaters = nil)
    if for_theaters.nil?
      TicketOrder.count( :conditions=>["orders.address_id = ? and orders.status in ( ? )",
                                       self.id, Order.attended_statuses])
    else
      TicketOrder.count(
        :conditions=>["orders.address_id = ? and orders.status in (?) and orders.performance_id in (select id from performances where production_id in (select id from productions where theater_id in (?)))",
                      self.id, Order.attended_statuses, for_theaters])
    end
  end

  def is_donor?
    DonationOrder.count(:include=>[:donation_line_items],
                        :conditions=>["orders.address_id = ? and line_items.donation_amount > 0",
                                      self.id]) > 0
  end

  def to_s
    "#{self.full_name} <#{self.email}>"
  end

  def last_attendance_date
    TicketOrder.includes(:performance).maximum('performance_date',:conditions=>["orders.address_id = ?", self.id])
  end

  def productions_attended(start_date = 10.years.ago, end_date = Time.now)
    TicketOrder.includes(:performance,{:performance=>:production}).where("orders.address_id = ? and orders.status in (?) and performances.performance_date >= ? and performances.performance_date <= ?",
                                                                         self.id,
                                                                         Order.attended_statuses,
                                                                         start_date, end_date).map{|o| o.performance.production}.uniq
  end

  private
  def name_as_searchable
    full_name.upcase
  end

  def create_salesforce_contact
    puts "  creating new sf record"
    SalesforceData::Contact.create "LastName"=>self.last_name, "FirstName"=>self.first_name, "stagemgr_id__c"=>"#{self.id}",
      "MailingStreet"=>"#{self.line1}\r\n#{self.line2}", "MailingCity"=>self.city,
      "Email"=>self.email, "Phone"=>self.phone,
      "MailingState"=>self.state, "MailingPostalCode"=>self.zipcode, "stagemgr_last_sync_at__c"=>DateTime.now

  end

end
