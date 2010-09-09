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

production  = theater.productions.create!({
  :name                      =>'Production 1', 
  :status                    =>Production::PRODUCTION_STATUSES.first, 
  :production_code           =>'T1P1', 
  :capacity                  =>350})
  
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
credit_card_order = Order.create!(        :payment_type=>Order::CREDIT_CARD, 
                                          :status=>Order::NEW, 
                                          :address=>address,
                                          :performance=>performance)
credit_card_order.ticket_line_items.create!(:ticket_class=>fixed_ticket_class, :ticket_count=>3)
credit_card_order.credit_card_payments.create!(
                                          :amount=>credit_card_order.total, 
                                          :card_number=>'4539992043491562',
                                          :card_expiration_month=>"1",
                                          :card_type=>"Visa",
                                          :card_verification_number=>"461",
                                          :card_expiration_year=>"2020",
                                          :confirmation_code=>"1234",
                                          :address => address)
credit_card_order.status=Order::PROCESSED
credit_card_order.save!

