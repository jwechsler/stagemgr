Stagemgr::Application.routes.draw do

  namespace(:admin){ resources :default_ticket_classes }

  get "donations/new"

  get "donations/confirm"

  get "donations/show"


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


    resources :addresses do

    end

    resources :flex_pass_offers do
      resources :orders, :controller => 'flex_pass_offer_orders'

    end

    resources :reports do
      collection do
        post :production_sales_by_performance
        post :flexpass_sales
        post :weekly_box_office
        post :daily_box_office_receipts
        post :order_dump
      end
    end

    resources :auto_complete do
      collection do
        get :production_code
        get :performance_code
        get :ticket_class_code
      end
    end
    resources :flex_passes
    resources :orders do
      collection do
        post :fulfill_selected
        post :credit_card_payment_form
        post :cash_payment_form
      end
      member do
        post :cancel
        post :refund
        get  :fulfill
        get :unclaimed
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
