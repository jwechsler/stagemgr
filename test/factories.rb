# FactoryBot.duplicate_attribute_assignment_from_initialize_with = false

module FactoryBot
  class << self
    def create_test_theater
      theater = FactoryBot.create(:theater, :name=>"Test Theater", theater_class: Theater::VISITING, accepts_donations: true)
      org_theater = FactoryBot.create(:theater, :name=>"Box Office Theater",theater_class: Theater::DEFAULT, accepts_donations: true)
      # Fixed point in next month: keeps the single performance in the future
      # (so the public order form isn't suppressed by the pre-show "in person
      # only" window) AND on a single box-office calendar page (the calendar
      # defaults to the production's first_preview_at month).
      show_date = Date.today.next_month.change(:day => 10)
      production = FactoryBot.create(:production, :theater=>theater, :name=>"Production One",
                          :production_code=>"TEST", :opening_at=>show_date, :press_opening_at=>show_date,
                          :first_preview_at=>show_date, :closing_at=>show_date + 1.week)
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
      performance = FactoryBot.create(:performance, :production=>production, :performance_code=>'TEST01',
                          :performance_date=>show_date, :performance_time=>"#{Date.today} 18:00".to_time)
      #
      performance.ticket_class_allocations.each do |tca|
        tca.available = true
        tca.save!
      end
    end
  end
end

FactoryBot.define do
  factory :job_metadatum do
    job_name { "MyString" }
    last_run_at { "2024-05-30 09:27:36" }
  end

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
    sequence(:last_name)     { |n| "Test#{n}" }
    sequence(:full_name)     { |n| "Jeremy Test#{n}" }
    first_name    { 'Jeremy' }
    line1         { '123 swift st' }
    city          { 'hoboken' }
    state         { 'ct' }
    zipcode       { '90210' }
    sequence(:email)         {|n| "jeremy#{n}@test.com" }
  end


  factory :ticket_line_item do
    association :ticket_class, :factory => :ticket_class
  end


  factory :donation_line_item do
    association :order, :factory=>:donation_order
  end


end

