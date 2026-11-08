Rails.application.routes.draw do
  resource :session
  resource :registration, only: %i[new create], path: "signup"
  resource :profile, only: %i[edit update]
  resource :theme, only: :update
  resource :lock, only: %i[show create destroy] do
    post :heartbeat
  end
  resource :lock_settings, only: :update
  resource :password, only: :update
  resource :onboarding, only: %i[show update]
  resource :inspiration, only: :show
  resources :invoices, only: %i[index create show] do
    get :preview, on: :collection, defaults: { format: :pdf }
  end
  root "dashboard#show"

  resources :time_entries, except: :show
  post "today", to: "time_entries#create_today", as: :today_entry

  get "reports", to: "reports#new", as: :reports
  get "reports/export", to: "reports#export", as: :export_report, defaults: { format: :pdf }

  namespace :admin do
    root "dashboard#show"
    resource :session, only: %i[new create destroy]
    resource :theme, only: :update
    resources :users do
      member do
        patch :reset_lock
        delete :sessions, action: :sign_out_everywhere, as: :sign_out_everywhere
      end
      resources :time_entries, except: %i[show new] do
        get :export, on: :collection, defaults: { format: :pdf }
      end
      resources :invoices, only: %i[index show create destroy] do
        get :preview, on: :collection, defaults: { format: :pdf }
      end
    end
    resources :administrators, except: :show
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
