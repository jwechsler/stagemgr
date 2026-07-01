Given(/^(?:|I )(?:|am |is )log(?:|ged)? in$/) do
  @current_test_user ||= FactoryBot.create(:user)
  visit new_user_session_path
  fill_in('Email', with: @current_test_user.email)
  fill_in('Password', with: 'password')
  click_button('Login')
end

Given(/^I am (|not )an [aA]dministrator$/) do |inverse|
  @current_test_user ||= FactoryBot.build(:user)
  @current_test_user.is_administrator = (inverse.empty? || false)
  @current_test_user.save_without_session_maintenance
end

Given(/^I am (|not |)a [bB]ox [oO]ffice [uU]ser$/) do |inverse|
  @current_test_user ||= FactoryBot.build(:user)
  @current_test_user.is_box_office_user = inverse.empty?
  @current_test_user.save_without_session_maintenance
end

Given(/^I am (|not |)a [tT]heat[er][re] [uU]ser$/) do |inverse|
  @current_test_user ||= FactoryBot.build(:user)
  @current_test_user.theaters << Theater.first if inverse.empty?
  @current_test_user.save_without_session_maintenance
end

Given(/^I log out$/) do
  click_link 'Logout'
end

Given 'debugger' do
  byebug
  true
end

Given('I wait for the datatable to load') do
  sleep(1.0 / 2.0)
  expect(page).to have_no_css('.dataTables_processing', visible: true)
end

# Utility method to dump text to the console
Then('output database content') do
  puts '*** DEBUGGING INFO:'
  addresses = Address.all
  if addresses.count.eql?(0)
    puts '  NO ADDRESSES IN DB!'
  else
    Address.all.each { |a| puts "  #{a}" }
  end
  memberships = Membership.all
  if memberships.count.eql?(0)
    puts '  Memberships: None'
  else
    memberships.each { |m| puts "  #{m}" }
  end
  puts '*** END'
end
