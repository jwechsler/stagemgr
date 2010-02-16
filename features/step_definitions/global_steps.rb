Given /^(?:|I )(don't |)have the role '(.+)'$/ do |inverse,role|
  @current_user ||= Factory(:user)
  if inverse.empty?
    @current_user.has_role(role)
  else
    @current_user.remove_role(role)
  end
end

Given /^(?:|I )(?:|am |is )logged in$/ do
  @current_user ||= Factory(:user)
  visit path_to('the login page')
  fill_in('user_session_email', :with=>@current_user.email)
  fill_in('user_session_password', :with=>'password')
  click_button('user_session_submit')
end
