ActionController::Routing::Routes.draw do |map|
  map.resources :theaters do |theater|
    theater.resources :productions
  end

  map.resource :account, :controller => "users"
  map.resources :users
  map.resource  :user_session
  map.root :controller => "user_sessions", :action => "new"
  map.login '/login', :controller => 'user_sessions', :action => 'new'
  map.logout '/logout', :controller => 'user_sessions', :action => 'destroy'

end
