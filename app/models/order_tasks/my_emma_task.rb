class MyEmmaTask < OrderTask
  attr_accessor :additional_groups

  protected

  def execute!
    add_show_to_myemma(order)
  end

  private

  def self.newsletter_id
    return if defined? @@newsletter_id

    group = MyEmma::Group.find_by_group_name('Newsletter')
    @@newsletter_id = group.id unless group.nil?
  end

  def self.coupon_id
    return if defined? @@coupon_id

    group = MyEmma::Group.find_by_group_name('Flash Offers')
    @@coupon_id = group.id unless group.nil?
  end

  def add_show_to_myemma(order)
    return if order.address.email.blank?

    member = MyEmma::Member.new

    groups = [MyEmmaTask.newsletter_id]
    groups += [MyEmmaTask.coupon_id]
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

    member.save(groups)
  end
end
