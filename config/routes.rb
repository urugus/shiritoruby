Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # API routes
  namespace :api do
    resources :games, only: [:index, :create] do
      collection do
        get :current, action: :show
        post :submit_word
        post :timeout
      end
    end
  end

  # Defines the root path route ("/")
  # TODO: 実際のゲーム画面コントローラを作成後に正しいパスへ変更する
  # root "games#index"
end
