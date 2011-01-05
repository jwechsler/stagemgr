Stagemgr::Application.routes.draw do

  resources :orders do
    post :confirm, :on => :collection
  end

  resources :productions, :only=>:index do
    resources :performances, :only=>:index do
      resources :orders, :controller => 'production_performance_orders'
    end
  end

  resources :flex_pass_offers, :only => false do
    resources :orders, :controller => 'flex_pass_offer_orders'
  end

  # add /productions/upcoming as list response for embedding on coming soon page.
  get '/productions/upcoming',
      :controller => 'productions',
      :action => 'upcoming'

  get '/productions/now_playing',
          :controller => 'productions',
          :action => 'now_playing'

  get '/productions/by_date',
          :controller => 'productions',
          :action => 'by_date'

  namespace :admin do
    resources :flex_pass_offers do
      resources :orders, :controller => 'flex_pass_offer_orders'
    end
    resources :flex_passes
    resources :orders do
      collection do
        get :autocomplete_production_code
        get :autocomplete_performance_code
        get :autocomplete_ticket_class_code
        post :fulfill_selected
        post :credit_card_payment_form
        post :cash_payment_form
      end
      member do
        post :cancel
        post :refund
        get  :fulfill
      end
      resources :exchange_orders, :only=>[:new,:create]
      resources :refund_orders, :only=>[:new,:create]
    end
    resources :special_offers
    resources :theaters do
      resources :productions do
        resources :performances do
          get 'duplicate', :on => :member
        end
        resources :ticket_classes
      end
    end
    resources :users do
      resources :theaters
    end
  end

  namespace :current_user do
    resources :theaters do
      resources :productions do
        resources :performances
      end
    end
    resource :account
  end

  resource  :user_session
  root :to => 'current_user/accounts#show'
  get '/login', :controller => 'user_sessions', :action => 'new'
  get '/logout', :controller => 'user_sessions', :action => 'destroy'

end
