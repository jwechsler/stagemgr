require 'resque/server'

Rails.application.routes.draw do
  mount StripeEvent::Engine, at: '/stripecb' # provide a custom path

  namespace(:admin) { resources :memberships }

  namespace(:admin) { resources :special_features }

  post 'venues/now_playing_fb'

  get 'venues/now_playing'
  get 'venues/now_playing_vertical'
  get 'venues/now_playing_fb'

  get 'venues/offtime_now_playing'

  get 'venues/primetime_up_next'

  get 'venues/offtime_up_next'

  get 'venue/primetime_now_playing'

  get 'venue/offnight_now_playing'

  get 'venue/primetime_up_next'

  get 'venue/offnight_up_next'

  # resque admin page
  mount Resque::Server.new, at: '/admin/resque', as: 'resque_admin'

  namespace(:admin) { resources :memberships }

  namespace(:admin) { resources :default_ticket_classes }

  namespace(:admin) do
    resources :service_item_templates
  end

  # get "donations/new"

  # get "donations/confirm"

  # get "donations/show"

  resources :donations, controller: 'donation_orders'

  resources :membership_orders do
    member do
      get :confirm
    end
  end

  # get "membership_orders/new"

  # get "membership_orders/create"

  # get "membership_orders/show"

  # get "membership_orders/edit"

  # get "membership_orders/confirm"

  # get "membership_orders/checkout"

  resources :orders do
    post :confirm, on: :collection
  end

  resources :ticket_orders do
    post :confirm, on: :member
  end

  resources :flex_pass_orders do
    post :confirm, on: :member
  end

  resources :donation_orders do
    post :confirm, on: :collection
  end

  resources :productions, only: :index do
    resources :performances, only: :index do
      resources :orders, controller: 'production_performance_orders'
    end
  end

  resources :performances, only: :index do
    resources :seat_assignments, only: :index, controller: 'seat_assignments' do
      collection do
        post :reserve, format: :json
        post :release, format: :json
        post :update_price_override, format: :json
      end
    end

    member do
      get :ticket_classes, constraints: ->(req) { req.format == :json }
    end

    collection do
      get :by_date
    end
  end

  resources :seat_assignments, only: :index do |_variable|
    collection do
      post :release_temporary, format: :json
      post :commit_reseating, format: :json
      post :rollback_reseating, format: :json
    end
  end

  resources :flex_pass_offers, only: :index do
    resources :orders, controller: 'flex_pass_offer_orders'
  end

  resources :membership_offers do
    resources :orders, controller: 'membership_offer_orders'
  end

  # add /productions/upcoming as list response for embedding on coming soon page.
  get '/productions/upcoming',
      controller: 'productions',
      action: 'upcoming'

  get '/productions/now_playing',
      controller: 'productions',
      action: 'now_playing'

  get '/productions/box_office', to: 'productions#box_office', as: 'box_office_productions'

  get '/festivals/:url_name', to: 'festivals#show', as: 'festival', constraints: { url_name: /[a-z0-9-]+/ }

  get '/productions/by_date',
      controller: 'productions',
      action: 'by_date'

  resources :productions, only: :show

  namespace :admin do
    resources :membership_orders, only: false

    resources :membership_orders do
      member do
        get :reactivate
        get :cancel
        post :update_seating
      end
    end

    resources :flex_pass_orders

    resources :addresses do
      collection do
        post :merge_selected, format: :json
        get :autocomplete_address
        get :autocomplete_tag
        get :autocomplete_address_tag_tag_label
      end
    end

    resources :flex_pass_offers do
      collection do
        get :autocomplete_tag
        get :search
        get :resolve_group
      end
      resources :orders, controller: 'flex_pass_offer_orders'
    end

    resources :festivals

    resources :membership_offers do
      collection do
        get :autocomplete_tag
        get :search
        get :resolve_group
      end
    end

    resources :membership_offers, only: false do
      resources :orders, controller: 'membership_offer_orders'
    end

    resources :reports do
      collection do
        post :production_sales_by_performance
        get :production_sales_by_performance, action: :index
        post :royalty_report
        get :royalty_report, action: :index
        post :flexpass_sales
        get :flexpass_sales, action: :index
        post :weekly_box_office
        get :weekly_box_office, action: :index
        post :daily_box_office_receipts
        get :daily_box_office_receipts, action: :index
        post :fulfill_tickets
        get :fulfill_tickets, action: :index
        post :order_dump
        get :order_dump, action: :index
        post :membership_usage
        get :membership_usage, action: :index
        get 'membership_usage/:membership_offer_id', action: :membership_usage, as: :membership_offer_usage
        post :membership_export
        post :membership_usage
        post :mine_customer_data
        get :mine_customer_data, action: :index
        post :house_management_seating
        get :house_management_seating, action: :index
        post :trg_dump
        post :attended_dump
        post :donation_dump
        post :donations_total
        post :flex_pass_patron_report
      end
    end

    resources :analysis, only: [:index] do
      collection do
        get :search_theaters
        post :rate_of_sales
        post :ticket_revenue
        post :audience
        post :audience_export
      end
    end

    resources :auto_complete do
      collection do
        get :production_code
        get :performance_code
        get :ticket_class_code
        get :address
      end
    end

    resources :orders do
      collection do
        post :unclaim_selected
        post :fulfill_selected
        post :credit_card_payment_form
        post :cash_payment_form
      end
      member do
        post :cancel
        post :refund
        get  :fulfill
        post :fulfill
        get :unclaimed
        post :update_notes
      end
      resources :refund_orders, only: %i[new create]
    end

    resources :donation_orders do
      collection do
        post :fulfill_selected
      end
      member do
        post :cancel
        post :refund
        get  :fulfill
      end
    end

    resources :ticket_orders do
      collection do
        post :fulfill_selected
        post :credit_card_payment_form
        post :cash_payment_form
        post :new_for_production
        get :autocomplete_production_production_code
        get :autocomplete_performance_performance_code
        get :autocomplete_ticket_line_item_ticket_class_code
        get :autocomplete_special_offer_special_offer_code
      end
      member do
        post :cancel
        post :cancel_held_during_seating
        post :refund
        post :convert_to_donation
        get :split
        patch :finalize_split
        get :fulfill
        get :reprint
        get :unclaimed
        post :confirm
        get :resend_confirmation
        post :update_notes
      end
      resources :exchange_ticket_orders, only: %i[new create]
      resources :refund_orders, only: %i[new create]
    end
    resources :service_line_items, only: [:destroy]
    resources :special_offers do
      post 'duplicate', on: :member
    end
    resources :payment_types do
      get :new_external_payment, on: :collection
      post :create_external_payment, on: :collection
    end

    resources :imports do
      post :mailing_cards, on: :collection
      post :external_contacts, on: :collection
      post :bulk_orders, on: :collection
      post :bulk_flex_pass_orders, on: :collection
      post :donation_levels, on: :collection
    end

    resources :productions, only: [:index] do
      collection do
        get :search
        get :resolve_group
      end
    end

    resources :theaters do
      collection do
        get :autocomplete_tag
      end
      resources :productions do
        post 'send_sample_confirmation', on: :member
        post 'send_sample_followup', on: :member
        get 'allocation_sync_status', on: :member
        resources :performances do
          get 'duplicate', on: :member
          post 'release_held_seats', on: :member
          get 'email_attendees_form', on: :member
          post 'send_broadcast', on: :member
        end
        resources :ticket_classes
      end
    end

    resources :venues do
      resources :seat_maps do
        member do
          get :editor
          get :editor_data
          post :bulk_update_seats
        end
      end
    end

    resources :users do
      resources :theaters
    end

    resources :performances do
      get :seating_quickview, on: :member
    end

    resources :performance, only: [:destroy]

    get '/system_options', controller: 'system_options', action: 'index'
  end

  namespace :current_user do
    resources :theaters do
      resources :productions do
        resources :performances
      end
    end
    resource :account
  end

  resource :user_session
  root to: 'current_user/accounts#show'
  get '/login', controller: 'user_sessions', action: 'new'
  delete '/logout', controller: 'user_sessions', action: 'destroy'
end
