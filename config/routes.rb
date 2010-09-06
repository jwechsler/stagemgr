ActionController::Routing::Routes.draw do |map|

  map.resources :productions, :only=>:index do |production|
    production.resources :performances, :only=>:index do |performance|
      performance.resources :orders
    end
  end

  # add /productions/upcoming as list response for embedding on coming soon page.
  map.connect '/productions/upcoming',
      :controller => 'productions',
      :action => 'upcoming'

  map.namespace :admin do |admin|
    admin.resources :flex_pass_offers do |flex_pass_offer|
      flex_pass_offer.resources :orders, :controller => 'flex_pass_offer_orders'
    end
    admin.resources :flex_passes
    admin.resources :orders, :collection => {
      :autocomplete_production_code => :get,
      :autocomplete_performance_code => :get,
      :autocomplete_ticket_class_code => :get,
      :credit_card_payment_form => :post,
      :cash_payment_form => :post
      }, :member => {:cancel=>:post, :refund=>:post, :fulfill=>:post} do |order|
      order.resources :exchange_orders, :only=>[:new,:create,:show]
    end
    admin.resources :special_offers
    admin.resources :theaters do |theater|
      theater.resources :productions do |production|
        production.resources :performances, :member => 'duplicate'
        production.resources :ticket_classes
      end
    end
    admin.resources :users do |user|
      user.resources :theaters
    end
  end

  map.namespace :current_user do |current_user|
    current_user.resources :theaters do |theater|
      theater.resources :productions do |production|
        production.resources :performances
      end
    end
    current_user.resource :account
  end

  map.resource  :user_session
  map.root :controller => "current_user/accounts", :action => "show"
  map.login '/login', :controller => 'user_sessions', :action => 'new'
  map.logout '/logout', :controller => 'user_sessions', :action => 'destroy'

end
