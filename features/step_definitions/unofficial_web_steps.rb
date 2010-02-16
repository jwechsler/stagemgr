Given /^(?:|I )should (|not )see a link labeled '(.+)'$/ do |is_not,link_label|
  if(is_not=='not ')
    assert page.has_no_xpath?(Capybara::XPath.link(link_label))
  else
    save_and_open_page unless page.has_xpath?(Capybara::XPath.link(link_label))
    assert page.has_xpath?(Capybara::XPath.link(link_label))
  end
end