module NavigationHelpers
  # Maps a name to a path. Used by the
  #
  #   When /^I go to (.+)$/ do |page_name|
  #
  # step definition in web_steps.rb
  #
  def path_to(page_name)
    @using_admin_interface = false
    case page_name

      when /the home\s?page/
        '/'
      when /^the login page$/
        url_for(:controller => 'user_sessions', :action => 'new', :only_path => true)
      when /^the logout page$/
        logout_path
      when /^the admin[\/| ]theaters? page$/
        @using_admin_interface = true
        url_for(:controller => 'admin/theaters', :action => 'index', :only_path => true)
      when /^the admin detail page for theater ["'](.*)['"]$/
        @using_admin_interface = true
        url_for(:controller => 'admin/theaters', :action => 'show', :id => Theater.find_by_name($1).id, :only_path => true)
      when /^the admin edit page for user ["'](.*)['"]$/
        @using_admin_interface = true
        url_for(controller: 'admin/users', action: 'edit', id: User.find_by_email($1), only_path:true)
      when /^the admin theater edit page for production "([^"]*)"$/
        @using_admin_interface = true
        url_for(:controller => 'admin/theaters', :action => 'edit', :id => Production.find_by_name($1).theater.id, :only_path => true)
      when /^the admin theater detail page for production "([^"]*)"$/
        @using_admin_interface = true
        admin_theater_path(Production.find_by_name($1).theater)
      when /^the admin production detail page for "([^"]*)"$/
        @using_admin_interface = true
        production = Production.find_by_name($1)
        admin_theater_production_path(production.theater, production)
      when /^the admin production edit page for "([^"]*)"$/
        @using_admin_interface = true
        production = Production.find_by_name($1)
        edit_admin_theater_production_path(production.theater, production)
      when /^New Box Office Order$/
        url_for(:controller => 'admin/ticket_orders', :action => 'new', :only_path => true)
      when /^new web order for production "([^"]*)" and performance "([^"]*)"/
        new_production_performance_order_url(Production.find_by_name($1).id, Performance.find_by_performance_code($2).id)
      when /^the box office calendar for production "([^"]*)"/
        production_performances_path(Production.find_by_name($1))
      when /^(the )?new membership order for membership offer "([^"]*)"/
        @_current_form='membership_order'
        new_membership_offer_order_url(MembershipOffer.find_by_name($2).id)
      when /^the admin edit page for membership offer "([^"]*)"/
        @using_admin_interface = true
        edit_admin_membership_offer_url(MembershipOffer.find_by_name($1))
      when /^(the )?new donation order$/
        @_current_form='donation_order'
        new_donation_order_url
      when /^(the |a )?new monthly pledge$/
        @_current_form='donation_pledge_order'
        new_donation_pledge_order_url
      when /^new admin ticket order$/
        @using_admin_interface = true
        new_admin_ticket_order_url
      when /^the admin ticket order detail page$/
        @using_admin_interface = true
        admin_ticket_order_url(TicketOrder.last)
      when /^the admin order page for the (.*)$/
        @using_admin_interface = true
        page_type = "#{$1}".gsub(' ','_')
        admin_order_path(eval "@#{page_type}.id")
      when /^the admin membership offers page$/
        @using_admin_interface = true
        admin_membership_offers_path
      when /^the new admin membership offer page$/
        @using_admin_interface = true
        new_admin_membership_offer_path
      when /^the system options page$/
        @using_admin_interface=true
        admin_system_options_path
      when /^the manage payment types page$/
        @using_admin_interface=true
        admin_payment_types_path
      when /^the address page for "([^"]*)"$/
        @using_admin_interface=true
        admin_address_path(Address.find_by_full_name($1))
      when /^the edit address page for "([^"]*)"$/
        @using_admin_interface=true
        edit_admin_address_path(Address.find_by_full_name($1))
      when /^the edit page for payment type "([^"]*)"$/
        @using_admin_interface=true
        edit_admin_payment_type_path(PaymentType.find_by_display_name($1))
      when /^the new special feature page$/
        @using_admin_interface=true
        new_admin_special_feature_path
      # Add more mappings here.
      # Here is an example that pulls values out of the Regexp:
      #
      #   when /^(.*)'s profile page$/i
      #     user_profile_path(User.find_by_login($1))

      else
        begin
          page_name =~ /the (.*) page/
          path_components = $1.split(/\s+/)
          self.send(path_components.push('path').join('_').to_sym)
        rescue Object => e
          raise "Can't find mapping from \"#{page_name}\" to a path.\n" +
                   "Now, go and add a mapping in #{__FILE__}"
        end
      end
    end
end

World(NavigationHelpers)
