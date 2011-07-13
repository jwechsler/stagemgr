require 'exceptions.rb'

class MembershipOffer < ActiveRecord::Base
  attr_accessible :name, :recurring_cost, :email_html, :interval_in_months, :use_ticket_class_code, :tickets_per_performance

  def verify_applicable_for(order)
    if !self.tickets_per_performance.nil?
      perfs = Order.where("performance_id = ? and id in (select order_id from payments where type = 'MembershipPayment')", order.performance_id)
      raise Exceptions::TooManyTicketsForMembership.new("This membership allows you #{self.tickets_per_performance} seat#{'s' if self.tickets_per_performance > 1} per performance") if self.tickets_per_performance < perfs.inject(0) { |sum, o1| sum += o1.membership_payments.inject(0) { |sum, p| sum += p.number_of_tickets } }
    end
  end
end
