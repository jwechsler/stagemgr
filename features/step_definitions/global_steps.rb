Given /^(?:|I )(?:|am |is )logged in$/ do
  @current_user ||= Factory(:user)
  visit path_to('the login page')
  fill_in('user_session_email', :with=>@current_user.email)
  fill_in('user_session_password', :with=>'password')
  click_button('user_session_submit')
end
