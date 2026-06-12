class AddAddressToMyEmmaJob
  @queue = :sync

  def self.newsletter_id
    return if defined? @@newsletter_id

    group = MyEmma::Group.find_by_group_name('Newsletter')
    @@newsletter_id = group.id unless group.nil?
  end

  def self.perform(address_id, production_id = nil, additional_groups = nil)
    production = Production.find(production_id) unless production_id.nil?
    address = Address.find(address_id)

    return if address.email.blank?

    member = MyEmma::Member.find_by_email(address.email) || MyEmma::Member.new

    groups = [AddAddressToMyEmmaJob.newsletter_id]
    additional_groups.each { |grp| groups << grp if grp.present? } unless additional_groups.nil?
    groups << production.use_myemma_attendee_group unless production.nil? || production.use_myemma_attendee_group.blank?
    member.name_first = address.first_name
    member.name_last = address.last_name
    member.email = address.email
    member.wildcard_1403237 = 'Every other week'
    member.address = address.line1
    member.city = address.city
    member.state = address.state
    member.postal_code = address.zipcode

    member.save(groups)
  end
end
