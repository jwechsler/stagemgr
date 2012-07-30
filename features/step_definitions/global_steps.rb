Given /^(?:|I )(?:|am |is )logged in$/ do
  @current_test_user ||= Factory(:user)
  visit path_to('the login page')
  fill_in('Email', :with=>@current_test_user.email)
  fill_in('Password', :with=>'password')
  click_button('Login')
end

Given /^I am (|not )an Administrator$/ do |inverse|

  @current_test_user ||= FactoryGirl.build(:user)
  if inverse.empty?
    @current_test_user.is_administrator = true
  else
    @current_test_user.is_administrator = false
  end
  @current_test_user.save_without_session_maintenance

end
