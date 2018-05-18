require "authlogic/test_case"
Before do
  activate_authlogic
end


Given /^(?:|I )(?:|am |is )log(?:|ged)? in$/ do
  @current_test_user ||= Factory(:user)
  UserSession.create(@current_test_user) # logs a user in
end

Given /^I am (|not )an [aA]dministrator$/ do |inverse|

  @current_test_user ||= FactoryBot.build(:user)
  if inverse.empty?
    @current_test_user.is_administrator = true
  else
    @current_test_user.is_administrator = false
  end
  @current_test_user.save_without_session_maintenance

end

Given /^I am (|not |)a [bB]ox [oO]ffice [uU]ser$/ do |inverse|

  @current_test_user ||= FactoryBot.build(:user)
  @current_test_user.is_box_office_user = inverse.empty?
  @current_test_user.save_without_session_maintenance

end

Given /^I am (|not |)a [tT]heat[er][re] [uU]ser$/ do |inverse|

  @current_test_user ||= FactoryBot.build(:user)
  if inverse.empty?
    @current_test_user.theaters << Theater.first
  end
  @current_test_user.save_without_session_maintenance

end

Given /^I log out$/ do
  page.driver.submit :delete, path_to("the logout page"), {}
end

