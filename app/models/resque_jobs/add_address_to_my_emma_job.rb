class AddAddressToMyEmmaJob
  @queue = :sync

  def self.perform(address_id, production_id = nil, additional_groups = nil)
    production = Production.find(production_id) unless production_id.nil?
    address = Address.find(address_id)

    return if address.email.blank?

    member = MyEmma::Member.find_by_email(address.email) || MyEmma::Member.new

    # Group names and the caching of their ids live in MyEmmaGroups; a blank
    # name in server.yml contributes nothing, hence the compact below.
    groups = [MyEmmaGroups.id_for(MyEmmaGroups::NEWSLETTER)]
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

    member.save(groups.compact)
  end
end
