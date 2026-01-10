Rails.application.routes.draw do
  resources :chats do
    resources :messages, only: [:create]
  end
  resources :models, only: [:index, :show] do
    collection do
      post :refresh
    end
  end
  # User dashboard
  get "home", to: "home#index", as: :home

  # User authentication (magic link - creates user on first use)
  resource :session, only: [ :new, :create, :destroy ]
  get "auth/:token", to: "sessions#verify", as: :verify_magic_link

  # Admin authentication (admin management happens in Avo)
  namespace :admins do
    resource :session, only: [ :new, :create, :destroy ]
    get "auth/:token", to: "sessions#verify", as: :verify_magic_link
  end

  # Avo admin panel (requires admin authentication)
  # Access at /avo - all admin management happens here
  mount Avo::Engine, at: Avo.configuration.root_path

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "home#index"
end
