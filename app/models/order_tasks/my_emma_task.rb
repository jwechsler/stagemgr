class MyEmmaTask < OrderTask
  attr_accessor :additional_groups

  protected

  def execute!
    add_show_to_myemma(order)
  end

  private

  def self.newsletter_id
    unless defined? @@newsletter_id
      group = MyEmma::Group.find_by_group_name("Newsletter")
      @@newsletter_id = group.id unless group.nil?
    end
  end

  def self.coupon_id
    unless defined? @@coupon_id
      group = MyEmma::Group.find_by_group_name("Flash Offers")
      @@coupon_id = group.id unless group.nil?
    end
  end

  def add_show_to_myemma(order)
    result = true

    unless order.address.email.blank?
      member = MyEmma::Member.new

      groups = [MyEmmaTask.newsletter_id]
      groups += [MyEmmaTask.coupon_id]
      additional_groups.each{|grp| groups << grp unless grp.blank?} unless additional_groups.nil?
      groups << order.performance.production.use_myemma_attendee_group unless order.performance.nil? || order.performance.production.use_myemma_attendee_group.blank?
      member.name_first = order.address.first_name
      member.name_last = order.address.last_name
      member.email = order.address.email
      member.address = order.address.line1
      member.city = order.address.city
      member.state = order.address.state
      member.postal_code = order.address.zipcode

      result = member.save(groups)
    end

  end

end

