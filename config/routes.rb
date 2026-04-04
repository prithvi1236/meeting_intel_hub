Rails.application.routes.draw do
  resource :session, only: %i[new create destroy]
  get "login", to: "sessions#new", as: :login
  resources :registrations, only: %i[new create]
  get "signup", to: "registrations#new", as: :signup
  resources :passwords, param: :token

  root "dashboard#index"
  get "dashboard/project_stats/:id", to: "dashboard#project_stats", as: :dashboard_project_stats

  resources :projects do
    resources :project_assignee_contacts, only: %i[index create update destroy]
    resources :followup_drafts, only: %i[index] do
      collection do
        patch :confirm_all
        patch :dismiss_all
      end
    end
    post "followup_drafts/generate", to: "followup_drafts#generate_for_project", as: :project_followup_drafts_generate

    resources :transcript_previews, only: %i[create]
    resources :meeting_imports, only: %i[create]
    resources :meetings do
      resources :transcripts, only: %i[create]
      resources :extracted_items, only: %i[index update destroy]
      resources :chat_sessions, only: %i[create show destroy] do
        member do
          delete :clear_messages
        end
        resources :chat_messages, only: %i[create]
      end
      member do
        get :sentiment
        post :reprocess
      end

      post "followup_drafts/generate", to: "followup_drafts#generate_for_meeting", as: :meeting_followup_drafts_generate
      resources :followup_drafts, only: %i[index update], shallow: true do
        collection do
          patch :confirm_all
          patch :dismiss_all
        end
        member do
          patch :dismiss
        end
      end
    end
    resources :chat_sessions, only: %i[index new create show destroy] do
      member do
        delete :clear_messages
      end
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
