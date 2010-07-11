ActionController::Routing::Routes.draw do |map|
  map.resources :productions, :only=>:index do |production|
    production.resources :performances, :only=>:index do |performance|
      performance.resources :orders
    end
  end
  
  map.namespace :admin do |admin|
    admin.resources :orders, :collection => { 
      :autocomplete_production_code => :get,
      :autocomplete_performance_code => :get,
      :autocomplete_ticket_class_code => :get,
      :credit_card_payment_form => :post,
      :cash_payment_form => :post
      }, :member => {:cancel=>:post, :refund=>:post, :exchange=>:get, :fulfill=>:post}
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
