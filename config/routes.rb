Rails.application.routes.draw do
  draw :madmin

  # User authentication (magic link - creates user on first use)
  resource :session, only: [ :new, :create, :destroy ]
  get "auth/:token", to: "sessions#verify", as: :verify_magic_link

  # Admin authentication (admin management happens in Madmin)
  namespace :admins do
    resource :session, only: [ :new, :create, :destroy ]
    get "auth/:token", to: "sessions#verify", as: :verify_magic_link
  end

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
    resources :members, only: [ :index, :new, :create, :destroy ], controller: "teams/members"
  end

  # Madmin admin panel (requires admin authentication)
  # Access at /madmin - all admin management happens here
  # Routes defined in config/routes/madmin.rb

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Root redirects to teams index (which handles single-team redirect)
  root "teams#index"
end
