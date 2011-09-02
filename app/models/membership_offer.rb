require 'exceptions.rb'

class MembershipOffer < ActiveRecord::Base
  attr_accessible :name, :recurring_cost, :email_html, :html_description, :use_ticket_class_code, :tickets_per_performance, :billing_agreement, :myemma_group
  validates_presence_of :name,:use_ticket_class_code,:recurring_cost,:tickets_per_performance
  validates_numericality_of :tickets_per_performance

end
