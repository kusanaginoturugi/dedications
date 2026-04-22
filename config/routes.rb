Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  resource :session, only: [ :new, :create, :destroy ]
  resources :orders, only: [ :index, :new, :create, :show, :edit, :update, :destroy ] do
    collection do
      get :summary
      get :personal_summary
    end
  end
  get "reports/pre_event", to: "reports#pre_event", as: :pre_event_reports
  get "reports/proxy_inventory", to: "reports#proxy_inventory", as: :proxy_inventory_reports
  get "reports/dedication_counts", to: "reports#dedication_counts", as: :dedication_counts_reports
  get "reports/dedication_counts/:form_type", to: "reports#dedication_counts", as: :dedication_counts_by_type_reports
  resources :congregations, only: :index
  resources :users, only: [ :index, :new, :create, :edit, :update ]

  root "orders#index"
end
