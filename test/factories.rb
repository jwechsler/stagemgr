Factory.define(:default_ticket_class) do |default_ticket_class|
  default_ticket_class.web_visible false
  default_ticket_class.ticket_price 0
  default_ticket_class.ticketing_fee 0
end

Factory.define(:user) do |user|
  user.sequence(:email) {|n| "stagemgr#{n}@example.com"}
  user.password 'password'
  user.password_confirmation 'password'
end

Factory.define(:address) do |address|
  address.last_name 'test'
  address.line1 '123 swift st'
  address.city  'hoboken'
  address.state 'ct'
  address.zipcode 90210
end

Factory.define(:venue) do |venue|
  venue.sequence(:name){|n|"Space #{n}"}
  venue.sequence(:ordinal_sort){|n| "#{n}"}
end
Factory.define(:theater) do |theater|
  theater.sequence(:name){|n|"Theater \##{n}"}
  theater.theater_class Theater::THEATER_CLASSES.first
  theater.status Theater::THEATER_STATUSES.first
end

Factory.define(:production) do |production|
  production.sequence(:name){|n|"Production \##{n}"}
  production.sequence(:production_code){|n|"PRO#{'%02d' % n}"}
  production.status Production::PRODUCTION_STATUSES.first
  production.association :theater, :factory => :theater
  production.association :venue, :factory=>:venue
  production.capacity 100
end

Factory.define(:performance) do |performance|
  performance.association :production, :factory => :production
  performance.status Performance::PERFORMANCE_STATUSES.first
  performance.sequence(:performance_code){|n|"PF#{'%02d' % n}"}
  performance.ticket_class_allocations{|perf|perf.populate_ticket_class_allocations}
end

Factory.define(:ticket_class) do |ticket_class|
  ticket_class.ticket_type TicketClass::TICKET_TYPES.first
  ticket_class.ticket_price 5.0
  ticket_class.sequence(:class_code){|n|"CS#{'%02d' % n}"}
end

Factory.define(:order) do |order|
  order.status Order::ORDER_STATUSES.first
  order.association :address, :factory => :address
end

Factory.define(:line_item) do |line_item|
  line_item.association :order, :factory        => :order
end

Factory.define(:ticket_line_item) do |ticket_line_item|
  ticket_line_item.association :order, :factory        => :order
  ticket_line_item.association :ticket_class, :factory => :ticket_class
end

Factory.define(:amount_off_special_offer) do |special_offer|
  special_offer.amount 1
  special_offer.sequence(:code){|n|"SpecialOffer#{n}"}
end

Factory.define(:cash_payment) do |cash_payment|
  cash_payment.amount 0
end

Factory.define(:membership_offer) do |offer|
  offer.name 'Test membership'
  offer.recurring_cost BigDecimal("5.00")
  offer.use_ticket_class_code 'MEMBER'
end

Factory.define(:membership_payment) do |payment|
  payment.amount 0
end