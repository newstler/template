# Below are the routes for madmin
namespace :madmin do
  namespace :active_storage do
    resources :variant_records
  end
  namespace :active_storage do
    resources :attachments
  end
  namespace :active_storage do
    resources :blobs
  end
  resources :admins do
    member do
      post :send_magic_link
    end
  end
  resources :chats
  resources :messages
  resources :models do
    collection do
      post :refresh_all
    end
  end
  resources :tool_calls
  resources :users
  resources :teams
  resource :settings, only: [ :show, :edit, :update ]
  root to: "dashboard#show"
end
