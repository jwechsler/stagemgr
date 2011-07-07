class MembershipOffer < ActiveRecord::Base
  attr_accessible :name, :recurring_cost, :email_html, :interval_in_months
end
