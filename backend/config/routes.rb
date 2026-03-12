Rails.application.routes.draw do
  # Salud / raíz
  root to: "health#show"
  get  "/up", to: "health#show"

  # Devise
  devise_for :users,
             path: '',
             path_names: { sign_in: 'users/sign_in', sign_out: 'users/sign_out' },
             controllers: { sessions: 'users/sessions' }

  # Rutas públicas (sin autenticación) - ANTES del defaults
  namespace :public, defaults: { format: :json } do
    resource :club, only: [:show], controller: 'club'
    resources :geneticas, only: [:index, :show]
    resources :noticias, only: [:index, :show]
    resources :eventos, only: [:index, :show]
    resources :galeria, only: [:index], controller: 'galeria'
  end

  # Rutas protegidas (requieren autenticación)
  defaults format: :json do
    get "/me",    to: "me#show"
    get "/stats", to: "stats#show"

    resources :salas do
      resources :lotes, only: [:index, :create]
    end

    resources :lotes, only: [:index, :show, :update, :destroy]
    resources :plants

    resources :socios do
      resources :notas, controller: "socio_notas", only: [:index, :create]
    end
    resources :socio_notas, only: [:destroy]

    # Recursos protegidos para admin
    resources :geneticas
    resources :noticias
    resources :eventos

    resource :profile, only: [:show, :update], controller: "profile" do
      patch :password
      patch :avatar
    end

    resource :preferences, only: [:show, :update], controller: "preferences" do
      post :upload_logo, on: :collection
    end

    resources :usuarios, controller: :club_users do
      member { post :reset_password }
    end
  end
end