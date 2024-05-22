# FactoryBot.duplicate_attribute_assignment_from_initialize_with = false

module FactoryBot
  class << self
    def create_test_theater
      theater = FactoryBot.create(:theater, :name=>"Test Theater", theater_class: Theater::VISITING, accepts_donations: true)
      org_theater = FactoryBot.create(:theater, :name=>"Box Office Theater",theater_class: Theater::DEFAULT, accepts_donations: true)
      production = FactoryBot.create(:production, :theater=>theater, :name=>"Production One",
                          :production_code=>"TEST", :opening_at=>Date.today+1.day, :closing_at=>Date.today+1.day)
      FactoryBot.create(:ticket_class, :class_code=>'PASS', :class_name=>"Pass Ticket",
                          :ticket_price=>0.00, :web_visible=>false, :software_managed=>true,
                          :production=>production, :auto_attach=>true)

      FactoryBot.create(:ticket_class, :class_code=>'PASSFRIEND', :class_name=>"Pass Ticket",
                          :ticket_price=>0.00, :web_visible=>false, :software_managed=>true,
                          :production=>production)
      FactoryBot.create(:ticket_class, :class_code=>'CHEAP', :class_name=>"Cheap Ticket",
                          :ticket_price=>5.00, :web_visible=>true, :software_managed=>false,
                          :production=>production)
      FactoryBot.create(:ticket_class, :class_code=>'RICH', :class_name=>"Expensive Ticket",
                          :ticket_price=>10.00, :web_visible=>true, :software_managed=>false,
                          :production=>production)
      FactoryBot.create(:ticket_class, :class_code=>'SECRET', :class_name=>"Secret Ticket",
                          :ticket_price=>20.00, :web_visible=>false, :software_managed=>false,
                          :production=>production)
      FactoryBot.create(:cash_payment_type, :allow_for_public=>false)
      FactoryBot.create(:credit_card_payment_type, :allow_for_public=>true)
      FactoryBot.create(:flex_pass_payment_type, :allow_for_public=>true)
      FactoryBot.create(:membership_payment_type, :allow_for_public=>true)
      FactoryBot.create(:default_ticket_class, :class_code=>'PASS', :class_name=>"Pass Ticket",
                          :ticket_price=>1.00, :web_visible=>false, :software_managed=>true, :auto_attach=>true)
      FactoryBot.create(:default_ticket_class, :class_code=>'PASSFRIEND', :class_name=>"Pass Ticket",
                          :ticket_price=>0.00, :web_visible=>false, :software_managed=>true, :auto_attach=>true)
      production.reload
      performance = FactoryBot.create(:performance, :production=>production, :performance_code=>'TEST01', :performance_time=>"#{Date.today} 18:00".to_time)
      #
      performance.ticket_class_allocations.each do |tca|
        tca.available = true
        tca.save!
      end
    end
  end
end

FactoryBot.define do
  factory :rate_of_sale do
    day_of_sale { "2024-05-21" }
    production { nil }
    total_single_tickets { 1 }
    total_complimentary_tickets { 1 }
    gross_sales { "9.99" }
    processing_fees { "9.99" }
  end


  factory :user do
    sequence(:email) { |n| "stagemgr#{n}@example.com" }
    password              { 'password' }
    is_administrator      { 0 }
    factory :admin_user do
      is_administrator  { 1 }
    end
  end

  factory :address do
    last_name     { 'Test' }
    full_name     { 'Jeremy Test' }
    first_name    { 'Jeremy' }
    line1         { '123 swift st' }
    city          { 'hoboken' }
    state         { 'ct' }
    zipcode       { '90210' }
    email         { 'jeremy@test.com' }
  end

  factory :flex_pass_order do
    order
  end

  factory :ticket_line_item do
    association :ticket_class, :factory => :ticket_class
  end


  factory :donation_line_item do
    association :order, :factory=>:donation_order
  end


end

