ActionController::Routing::Routes.draw do |map|
  map.resources :orders

  map.resources :line_items

  map.resources :ticket_classes

  map.resources :theaters do |theater|
    theater.resources :productions do |production|
      production.resources :performances
    end
  end

  map.resource :account
  map.resources :users
  map.resource  :user_session
  map.root :controller => "user_sessions", :action => "new"
  map.login '/login', :controller => 'user_sessions', :action => 'new'
  map.logout '/logout', :controller => 'user_sessions', :action => 'destroy'

end
