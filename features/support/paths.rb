module NavigationHelpers
  # Maps a name to a path. Used by the
  #
  #   When /^I go to (.+)$/ do |page_name|
  #
  # step definition in web_steps.rb
  #
  def path_to(page_name)
    case page_name
    
    when /the home\s?page/
      '/'
    when /^the login page$/
      url_for(:controller=>'user_sessions',:action=>'new', :only_path=>true)
    when /^the admin\/theater page$/
      url_for(:controller=>'admin/theaters',:action=>'index', :only_path=>true)
    when /^the admin theater edit page for production "([^"]*)"$/
      url_for(:controller=>'admin/theaters', :action=>'edit', :id=>Production.find_by_name($1).theater.id, :only_path=>true)
    when /^the admin theater detail page for production "([^"]*)"$/
      url_for(:controller=>'admin/theaters', :action=>'show', :id=>Production.find_by_name($1).theater.id, :only_path=>true)
      
    
    # Add more mappings here.
    # Here is an example that pulls values out of the Regexp:
    #
    #   when /^(.*)'s profile page$/i
    #     user_profile_path(User.find_by_login($1))

    else
      raise "Can't find mapping from \"#{page_name}\" to a path.\n" +
        "Now, go and add a mapping in #{__FILE__}"
    end
  end
end

World(NavigationHelpers)
