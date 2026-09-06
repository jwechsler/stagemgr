class MyEmmaTask < OrderTask
  attr_accessor :additional_groups

  protected

  def execute!
    add_show_to_myemma(order)
  end

  private

  def add_show_to_myemma(order)
    return if order.address.email.blank?

    member = MyEmma::Member.new

    # Group names and the caching of their ids live in MyEmmaGroups; a blank
    # name in server.yml contributes nothing, hence the compact below.
    groups = [MyEmmaGroups.id_for(MyEmmaGroups::NEWSLETTER), MyEmmaGroups.id_for(MyEmmaGroups::COUPON)]
    additional_groups.each { |grp| groups << grp if grp.present? } unless additional_groups.nil?
    unless order.performance.nil? || order.performance.production.use_myemma_attendee_group.blank?
      groups << order.performance.production.use_myemma_attendee_group
    end
    member.name_first = order.address.first_name
    member.name_last = order.address.last_name
    member.email = order.address.email
    member.address = order.address.line1
    member.city = order.address.city
    member.state = order.address.state
    member.postal_code = order.address.zipcode

    member.save(groups.compact)
  end
end
