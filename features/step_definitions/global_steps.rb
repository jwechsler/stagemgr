Given /^(?:|I )(?:|am |is )log(?:|ged)? in$/ do
  @current_test_user ||= Factory(:user)
  visit path_to('the login page')
  fill_in('Email', :with=>@current_test_user.email)
  fill_in('Password', :with=>'password')
  click_button('Login')
end

Given /^I am (|not )an [aA]dministrator$/ do |inverse|

  @current_test_user ||= FactoryGirl.build(:user)
  if inverse.empty?
    @current_test_user.is_administrator = true
  else
    @current_test_user.is_administrator = false
  end
  @current_test_user.save_without_session_maintenance

end

Given /^I am (|not |)a [bB]ox [oO]ffice [uU]ser$/ do |inverse|

  @current_test_user ||= FactoryGirl.build(:user)
  @current_test_user.is_box_office_user = inverse.empty?
  @current_test_user.save_without_session_maintenance

end

Given /^I am (|not |)a [tT]heat[er][re] [uU]ser$/ do |inverse|

  @current_test_user ||= FactoryGirl.build(:user)
  if inverse.empty?
    @current_test_user.theaters << Theater.first
  end
  @current_test_user.save_without_session_maintenance

end

Given /^I log out$/ do
  page.driver.submit :delete, path_to("the logout page"), {}
end

