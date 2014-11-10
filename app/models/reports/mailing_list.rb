class MailingList < Report

  TRG_IMPORT_HEADERS = [:Segment, :Season, :Title, :FirstName, :LastName, :FullName, :CompanyName, :Email, :Address1, :Address2,
               :Address3, :City, :State, :Zip, :HomePhone, :BusinessPhone, :ClientPatronID]

  def initialize(reporting_user_id = nil)
    super(TRG_IMPORT_HEADERS, reporting_user_id)
    @data['ALL'] = Array.new
    @data['MEM'] = Array.new
    @data['STB'] = Array.new
    @data['EMA'] = Array.new
    @data['REN'] = Array.new
    @data['CMP'] = Array.new
  end

  def extract_addresses_from_ticket_orders(orders)

    order_set = orders.to_set
    order_address_set = orders.map{|o| o.address}.to_set

    order_set.each do |order|
      consolidation_code = order.performance.production.theater.is_default? ? 'ALL' : 'REN'
      season_tag = order.performance.production.season.to_i + 1
      address = order.address
      hash = MailingList.mailing_hash_from_buyer(address)
      hash[:Title] = order.performance.production.name
      hash[:Season] = season_tag
      hash[:AttendedOn] = order.performance.performance_date
      buyer_type = case
      when order.paid_with_membership?
        'MEM'
      when order.total == 0
        'CMP'
      else
        'STB'
      end
      self.data[consolidation_code] << hash
      self.data[buyer_type] << hash unless buyer_type.nil?
    end

  end


  def self.mailing_hash_from_buyer(address)
    Hash[:FirstName => address.first_name, :LastName=>address.last_name,
               :FullName => address.full_name, :CompanyName => '',
               :Email => address.email, :Address1 => address.line1,
               :Address2=>address.line2, :Address3=>'',
               :City=>address.city, :State => address.state,
               :Zip => address.zipcode,
               :HomePhone => address.phone, :BusinessPhone => '',
               :ClientPatronID => address.sf_contact_id ]
  end

  def self.trg_hash_from_myemma(member)

    Hash[:FirstName=> member.name_first, :LastName=>member.name_last,
               :FullName => "#{member.name_first} #{member.name_last}" , :CompanyName => '',
               :Email => member.email, :Address1 => member.address,
               :Address2=>'', :Address3=>'',
               :City=>member.city, :State => member.state,
               :Zip => member.postal_code,
               :HomePhone => '', :BusinessPhone => '',
               :ClientPatronID => '' ]
  end

end
