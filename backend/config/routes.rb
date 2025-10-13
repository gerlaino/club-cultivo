Rails.application.routes.draw do
  devise_for :users,
             path: '',
             path_names: { sign_in: 'users/sign_in', sign_out: 'users/sign_out' },
             controllers: { sessions: 'users/sessions' }

  get "/health", to: "health#show"
  get "/me",     to: "me#show"
  get "/stats",  to: "stats#show"

  resources :salas do
    resources :lotes, only: [:index, :create]  # /salas/:sala_id/lotes
  end

  resources :socios, defaults: { format: :json } do
    resources :notas, controller: "socio_notas", only: [:index, :create], defaults: { format: :json }
  end
  resources :socio_notas, only: [:destroy], defaults: { format: :json }
  resources :usuarios, defaults: { format: :json }

  resources :lotes,  only: [:show, :update, :destroy]
  resources :plants, only: [:show, :update, :destroy]

  resource :profile, only: [:show, :update], controller: "profile" do
    patch :password   # /profile/password
    patch :avatar     # /profile/avatar
  end

  resource :preferences, only: [:show, :update], controller: "clubs"

end
