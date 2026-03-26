Rails.application.routes.draw do
  resource :session, only: %i[new create destroy]
  get "login", to: "sessions#new", as: :login
  resources :registrations, only: %i[new create]
  get "signup", to: "registrations#new", as: :signup
  resources :passwords, param: :token

  root "dashboard#index"
  get "dashboard/project_stats/:id", to: "dashboard#project_stats", as: :dashboard_project_stats

  resources :projects do
    resources :meetings do
      resources :transcripts, only: %i[create destroy]
      resources :extracted_items, only: %i[index update destroy]
      resources :chat_sessions, only: %i[create show destroy] do
        resources :chat_messages, only: %i[create]
      end
      member do
        get :sentiment
        post :reprocess
      end
    end
    resources :chat_sessions, only: %i[index new create show] do
      resources :chat_messages, only: %i[create]
    end
  end

  namespace :api do
    namespace :v1 do
      resources :meetings, only: [] do
        member do
          get :export_items
        end
      end
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
