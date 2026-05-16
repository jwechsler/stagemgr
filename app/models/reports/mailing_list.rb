#
#  Basic utility routines to create/export data for TRG / direct mail uses
#
class MailingList < Report

  TRG_IMPORT_HEADERS = [:Segment, :Season, :Title, :FirstName, :LastName, :FullName, :CompanyName, :Email, :Address1, :Address2,
               :Address3, :City, :State, :Zip, :HomePhone, :BusinessPhone, :ClientPatronID, :StagemgrPatronID]

  # theater_ids drives the per-theater :ClientPatronID lookup for TRG
  # exports: `address.external_id(theater_ids)` returns the patron's id in
  # the external system tagged against any of these theaters. Defaults to
  # [] so callers that haven't been updated still emit blank ClientPatronID.
  # :StagemgrPatronID is always populated with address.id.
  attr_reader :theater_ids

  def initialize(reporting_user_id = nil, theater_ids: [])
    super(TRG_IMPORT_HEADERS, reporting_user_id)
    @theater_ids = Array(theater_ids).map(&:to_i)
    @data = Hash.new
    @data['ALL'] = Array.new
    @data['MEM'] = Array.new
    @data['STB'] = Array.new
    @data['EMA'] = Array.new
    @data['REN'] = Array.new
    @data['CMP'] = Array.new
    @data['LST'] = Array.new
    @data['DON'] = Array.new
    @processed_addresses = Hash.new
  end

  def extract_addresses_from_ticket_orders(orders, allow_email_export = false, email_attendees = nil)

    order_set = orders.select{|o| !o.performance.nil? && !o.performance.production.nil?}.to_set
    members_by_email = email_attendees || Hash.new
    order_set.each do |order|
      consolidation_code = (order.performance.production.theater.producing?) ? 'ALL' : 'REN'
      buyer_type = case
      when order.paid_with_membership?
        'MEM'
      when order.all_tickets_complimentary?
        'CMP'
      else
        'STB'
      end
      self.add_hash_to_data(consolidation_code, order.address, order.performance.production, buyer_type, order.performance.performance_date, allow_email_export, email_attendees)
    end
  end

  def extract_production_attendees(production, allow_email_export = false, email_attendees = nil)
    attendees = production.addresses
    attendees.each do |address|
      consolidation_code = production.theater.producing? ? 'ALL' : 'REN'
      self.add_hash_to_data(consolidation_code, address, production, consolidation_code, production.closing_at + 1.day, allow_email_export, email_attendees)
    end 
  end

  # Instance wrapper that threads the report's theater_ids context into the
  # class-level builder. Prefer this form from inside MailingList subclasses
  # so :ClientPatronID is consistently populated from the right theater
  # scope.
  def mailing_hash_from_buyer(address, allow_email_export = false)
    MailingList.mailing_hash_from_buyer(address, allow_email_export, theater_ids)
  end

  def self.mailing_hash_from_buyer(address, allow_email_export = false, theater_ids = [])
    Hash[:FirstName => address.first_name, :LastName=>address.last_name,
               :FullName => address.full_name, :CompanyName => '',
               :Address1 => address.line1,
               :Address2=>address.line2, :Address3=>'',
               :City=>address.city, :State => address.state,
               :Zip => address.zipcode,
               :Email => (allow_email_export ? address.email : ''),
               :HomePhone => address.phone, :BusinessPhone => '',
               :ClientPatronID => client_patron_id_for(address, theater_ids),
               :StagemgrPatronID => address.id ]
  end

  # Patron's id in the theater's external system (TRG, etc.), looked up via
  # AddressTag. Empty string when no external mapping is tagged for any of
  # the given theaters.
  def self.client_patron_id_for(address, theater_ids)
    ext = address.external_id(Array(theater_ids))
    ext.to_s.strip
  end

  private
  # adds address information to the data hash.  Only does so once per address_id
  def add_hash_to_data(consolidation_code, address, production, buyer_type, performance_date, allow_email_export, members_by_email)
    @processed_addresses[production.id] = Set.new if @processed_addresses[production.id].nil?
    unless @processed_addresses[production.id].include?(address.id)
     season_tag = production.season.to_i
      hash = self.mailing_hash_from_buyer(address, allow_email_export)
      unless hash[:Email].nil?
        unless allow_email_export || members_by_email.has_key?(hash[:Email].downcase)
          hash[:Email] = nil
        end
      end
      # :Title in TRG Arts is the segment title — the descriptive label for
      # the per-row list segment, not the patron's personal salutation.
      hash[:Title] = production.name
      hash[:Season] = season_tag
      hash[:AttendedOn] = performance_date
      
      self.data[consolidation_code] << hash
      theater_hash = hash.dup
      theater_hash[:Title] = "#{production.theater.name} Attendee"
      self.data[consolidation_code] << theater_hash.dup
      theater_hash[:Season] = ""
      self.data[consolidation_code] << theater_hash
      self.data[buyer_type] << hash unless buyer_type.nil?
      @processed_addresses[production.id] << address.id
    end
  end

end
