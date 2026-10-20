Rails.application.routes.draw do
  resource :session
  resource :registration, only: %i[new create], path: "signup"
  resource :profile, only: %i[edit update]
  resources :invoices, only: %i[index create show]
  root "dashboard#show"

  resources :time_entries, except: :show
  post "today", to: "time_entries#create_today", as: :today_entry

  get "reports", to: "reports#new", as: :reports
  get "reports/export", to: "reports#export", as: :export_report, defaults: { format: :pdf }

  get "up" => "rails/health#show", as: :rails_health_check
end
