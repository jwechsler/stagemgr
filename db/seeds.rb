# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ :name => 'Chicago' }, { :name => 'Copenhagen' }])
#   Major.create(:name => 'Daley', :city => cities.first)

user        = User.create!({
      :email                 => 'admin@yoursite.com',
      :password              => 'betterpassword',
      :password_confirmation => 'betterpassword',
      :is_administrator      => true})

theater     = Theater.create!({
  :name                      =>'Theater 1',
  :theater_class             =>Theater::THEATER_CLASSES.first,
  :status                    =>Theater::THEATER_STATUSES.first})

venue       = Venue.create!({
  :name                      =>'Venue 1',
  :ordinal_sort              => 1
})

production  = theater.productions.create!({
  :name                      =>'Production 1',
  :status                    =>Production::PRODUCTION_STATUSES.first,
  :venue                     =>venue,
  :production_code           =>'T1P1',
  :capacity                  =>350,
  :closing_at                =>Date.today + 5.months,
  :first_preview_at          =>Date.today - 1.months,})

fixed_ticket_class = production.ticket_classes.create!({
  :ticket_type               =>TicketClass::TICKET_TYPES.first,
  :class_name                =>'General Admission',
  :ticket_price              =>35,
  :web_visible               =>true,
  :class_code                =>'TC1'

})

donation_ticket_class = production.ticket_classes.create!({
  :ticket_type               =>TicketClass::TICKET_TYPES[1],
  :class_name                =>'General Admission',
  :ticket_price              =>35,
  :web_visible               =>true,
  :class_code                =>'TC2',
})

timed_ticket_class = production.ticket_classes.create!({
  :ticket_type               =>TicketClass::TICKET_TYPES[2],
  :class_name                =>'General Admission',
  :ticket_price              =>35,
  :web_visible               =>true,
  :class_code                =>'TC3'

})

performance = production.performances.create!({
  :status                    =>Performance::PERFORMANCE_STATUSES.first,
  :performance_code          =>'T1P10305'
})

production2  = theater.productions.create!({
  :name                      =>'Production 2',
  :status                    =>Production::PRODUCTION_STATUSES.first,
  :venue                     =>venue,
  :production_code           =>'T1P2',
  :capacity                  =>350})

performance2 = production2.performances.create!({
  :status                    =>Performance::PERFORMANCE_STATUSES.first,
  :performance_code          =>'T1P20305'
})

timed_ticket_class2 = production2.ticket_classes.create!({
  :ticket_type               =>TicketClass::TICKET_TYPES[2],
  :class_name                =>'General Admission',
  :ticket_price              =>35,
  :web_visible               =>true,
  :class_code                =>'TC4'

})

Performance.all.each do |per|
  per.populate_ticket_class_allocations
  per.ticket_class_allocations.each do |tca|
    tca.available=true
    tca.save!
  end
end


address = Address.create!(                :first_name=>'Bob',
                                          :last_name=>'Loblaw')
credit_card_order = Order.create!(        :payment_type=>CreditCardPaymentType.first,
                                          :status=>Order::NEW,
                                          :address=>address,
                                          :performance=>performance)

