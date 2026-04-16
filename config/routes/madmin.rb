# Below are the routes for madmin
namespace :madmin do
  resources :ai_costs
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
  resources :chats do
    collection do
      patch :toggle_ai_chats
    end
  end
  resources :messages
  resources :models do
    collection do
      post :refresh_all
    end
  end
  resources :tool_calls
  resources :users
  resources :teams
  resources :memberships
  resources :languages do
    collection do
      post :sync
      patch :update_currency
      patch :toggle_currency
      patch :bulk_toggle
      patch :bulk_toggle_currency
    end
    member do
      patch :toggle
    end
  end
  resource :settings, only: [ :show, :update ]
  resource :ai_models, only: [ :show, :update ], controller: "ai_models" do
    post :refresh_all, on: :member
    post :rebuild_embeddings, on: :member
  end
  resource :search, only: [ :show, :update ], controller: "rag" do
    post :rebuild_fts, on: :member
  end
  resources :providers, only: [ :index ] do
    collection do
      patch :update
    end
  end
  resource :prices, only: [ :show ] do
    post :sync, on: :member
  end
  resource :mail, only: [ :show, :update ], controller: "mail"
  resources :noticed_events, only: [ :index, :show ]
  resources :noticed_notifications, only: [ :index, :show ]
  resources :conversations do
    collection do
      patch :toggle_moderation
      patch :toggle_conversations
    end
  end
  resources :articles do
    collection do
      patch :toggle_articles
    end
  end
  resources :conversation_messages
  resources :conversation_participants, only: [ :index, :show ]
  resources :team_languages, only: [ :index, :show ]
  root to: "dashboard#show"
end
