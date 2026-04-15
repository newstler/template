Rails.application.routes.draw do
  mount RailsErrorDashboard::Engine => "/red"  # RED (Rails Error Dashboard) — also works at /error_dashboard
  mount MissionControl::Jobs::Engine, at: "/jobs"
  draw :madmin

  # User authentication (magic link - creates user on first use)
  resource :session, only: [ :new, :create, :destroy ]
  get "auth/:token", to: "sessions#verify", as: :verify_magic_link

  # Admin authentication (admin management happens in Madmin)
  namespace :admins do
    resource :session, only: [ :new, :create, :destroy ]
    get "auth/:token", to: "sessions#verify", as: :verify_magic_link
  end

  # Onboarding (first-time user setup, before team context)
  resource :onboarding, only: [ :show, :update ]

  # User notifications inbox (global — not team-scoped because a user may
  # receive notifications across multiple teams)
  resources :notifications, only: [ :index, :show ] do
    member do
      patch :mark_read
    end
    collection do
      patch :mark_all_read
    end
  end
  resource :notification_preferences, only: [ :edit, :update ],
           controller: "notifications/preferences"

  # Personal context (authenticated user, no team scope)
  get "home", to: "personal/home#show", as: :personal_home
  resource :profile, only: [ :edit, :update ], controller: "personal/profiles", as: :personal_profile

  # Team management (multi-tenant only routes for listing/creating teams)
  resources :teams, only: [ :index, :new, :create ], param: :slug

  # Team-scoped routes
  scope "/t/:team_slug", as: :team do
    root "home#index", as: :root
    resources :chats do
      resources :messages, only: [ :create ]
    end
    resources :models, only: [ :index, :show ]
    resource :models_refresh, only: [ :create ], controller: "models/refreshes"

    # Team settings (multi-tenant only)
    resource :settings, only: [ :show, :edit, :update ], controller: "teams/settings" do
      patch :regenerate_api_key
    end
    resource :name_check, only: [ :show ], controller: "teams/name_checks"
    resources :members, only: [ :index, :show, :new, :create, :destroy ], controller: "teams/members"
    resource :profile, only: [ :show, :edit, :update ], controller: "profiles"

    # Sidebar pagination
    get "sidebar/conversations", to: "teams/sidebar#conversations", as: :sidebar_conversations
    get "sidebar/chats", to: "teams/sidebar#chats", as: :sidebar_chats

    # Content
    resources :articles
    resources :languages, only: [ :index, :create, :destroy ], controller: "teams/languages"
    resources :conversations, controller: "teams/conversations", only: [ :index, :new, :create, :show ] do
      resources :messages, controller: "teams/conversations/messages", only: [ :create ]
      resources :participants, controller: "teams/conversations/participants", only: [ :show ]
    end

    # Billing
    resource :pricing, only: [ :show ], controller: "teams/pricing"
    resource :billing, only: [ :show ], controller: "teams/billing"
    resource :checkout, only: [ :create ], controller: "teams/checkouts"
    resource :subscription_cancellation, only: [ :create, :destroy ], controller: "teams/subscription_cancellations"
  end

  # Webhooks
  namespace :webhooks do
    resource :stripe, only: [ :create ], controller: "stripe"
  end

  # Madmin admin panel (requires admin authentication)
  # Access at /madmin - all admin management happens here
  # Routes defined in config/routes/madmin.rb

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # OG Image preview page (screenshot at 1200x630 for social sharing)
  get "og-image", to: "og_images#show"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Root redirects to teams index (which handles single-team redirect)
  root "teams#index"
end
