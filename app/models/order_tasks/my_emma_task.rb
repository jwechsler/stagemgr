class MyEmmaTask < OrderTask
  attr_accessor :additional_groups

  protected

  def execute!
    add_show_to_myemma(order)
  end

  private

  def self.newsletter_id
    unless defined? @@newsletter_id
      @@newsletter_id = MyEmma::Group.find_by_group_name("Customer").id
    end
  end


  def add_show_to_myemma(order)
    result = true

    unless order.address.email.blank?
      member = MyEmma::Member.new

      groups = [208104529]
      additional_groups.each{|grp| groups << grp unless grp.blank?} unless additional_groups.nil?
      groups << order.performance.production.myemma_attendee_group unless order.performance.nil? || order.performance.production.myemma_attendee_group.blank?
      member.name_first = order.address.first_name
      member.name_last = order.address.last_name
      member.email = order.address.email
      member.wildcard_1403237 = 'Every other week'
      member.address = order.address.line1
      member.city = order.address.city
      member.state = order.address.state
      member.postal_code = order.address.zipcode

      result = member.save(groups)
    end

  end

end
