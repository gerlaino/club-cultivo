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
    post '/asistente/parsear',  to: 'asistente#parsear'
    post '/asistente/ejecutar', to: 'asistente#ejecutar'

    resources :salas do
      resources :lotes, only: [:index, :create]
      resources :cultivadores, controller: 'sala_cultivadores', only: [:index, :create, :destroy]
    end

    resources :lotes, only: [:index, :show, :update, :destroy] do
      resource :costo, controller: :costo_lotes, only: [:show, :create, :update]
      resources :registros_ambientales, only: [:index, :create, :destroy]
      resources :lote_eventos,          only: [:index, :create]
      resources :fotos, only: [:index, :create], controller: 'fotos_lote'
    end

    resources :plants do
      resources :plant_activities, only: [:index, :create, :destroy]
    end

    resources :socios do
      resources :notas, controller: "socio_notas", only: [:index, :create]
      resources :indicaciones, controller: "indicacion_medica", only: [:index, :create]
      resources :dispensaciones, only: [:index, :create]
    end
    resources :indicaciones, controller: "indicacion_medica", only: [:show, :update, :destroy]
    resources :socio_notas, only: [:destroy]
    resources :dispensaciones, only: [:show, :update, :destroy]

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
      member do
        post   :reset_password
        get    :salas_asignadas
        post   :asignar_sala
        delete :desasignar_sala
        get    :sedes_asignadas
        post   :asignar_sede
        delete :desasignar_sede
      end
    end

    # Templates de documentos (admin)
    resources :document_templates

    # Documentos por paciente
    resources :socios do
      resources :documents, controller: 'patient_documents' do
        member do
          post  :firmar
          patch :archivar
        end
      end
      resources :notas, controller: "socio_notas", only: [:index, :create]
      resources :indicaciones, controller: "indicacion_medica", only: [:index, :create]
      resources :dispensaciones, only: [:index, :create]
    end

    # Plan info
    resource :plan, only: [:show], controller: 'plan'

    resources :documentos, only: [:index, :create, :destroy]

    # Sedes
    resources :sedes do
      member do
        get  :inventario
        post :agregar_stock
      end
    end

    resources :movimientos_contables, only: [:index, :show, :create, :update, :destroy] do
      collection do
        get :dashboard
        get :export_csv
      end
    end

    resource :informe_semestral, only: [:show], controller: :informe_semestral

    resources :tareas do
      collection do
        get :dashboard   # GET /api/v1/tareas/dashboard
        get :kanban      # GET /api/v1/tareas/kanban
      end
      member do
        post :iniciar    # POST /api/v1/tareas/:id/iniciar
        post :completar  # POST /api/v1/tareas/:id/completar
        post :cancelar   # POST /api/v1/tareas/:id/cancelar
      end
    end

  end

  # Super Admin — gestión global
  namespace :super_admin do
    resources :clubs, only: [:index, :show, :create, :update] do
      member do
        post :crear_usuarios_default
        patch :cambiar_plan
      end
    end
    resources :users, only: [:index, :create, :update, :destroy]
    get :stats, to: 'stats#show'
  end

end