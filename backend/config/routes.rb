Rails.application.routes.draw do
  # Salud / raíz
  root to: "health#show"
  get  "/up", to: "health#show"

  # Devise (como lo tenías)
  devise_for :users,
             path: '',
             path_names: { sign_in: 'users/sign_in', sign_out: 'users/sign_out' },
             controllers: { sessions: 'users/sessions' }

  # Todo lo “API” en JSON por defecto
  defaults format: :json do
    get "/me",    to: "me#show"
    get "/stats", to: "stats#show"

    resources :salas do
      resources :lotes, only: [:index, :create]  # /salas/:sala_id/lotes
    end

    resources :lotes,  only: [:show, :update, :destroy]
    resources :plants, only: [:show, :update, :destroy]

    resources :socios do
      resources :notas, controller: "socio_notas", only: [:index, :create]
    end
    resources :socio_notas, only: [:destroy]

    resource  :profile, only: [:show, :update], controller: "profile" do
      patch :password   # /profile/password
      patch :avatar     # /profile/avatar
    end

    resource :preferences, only: [:show, :update], controller: "clubs"

    # Usuarios del club (NO duplicar este recurso)
    resources :usuarios, controller: :club_users do
      member { post :reset_password }
    end
  end
end