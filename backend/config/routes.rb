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
  resources :lotes, only: [:show, :update, :destroy]  # /lotes/:id

end