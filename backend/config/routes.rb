Rails.application.routes.draw do
  mount ActionCable.server => '/cable'

  # Health check (usar este path en Render): responde JSON aunque no haya SPA buildeada.
  get  "/up", to: "health#show"
  # Root sirve la SPA (index.html copiado a public/). Si no hay build, spa_fallback
  # responde 404 — por eso el health check de Render debe apuntar a /up, no a /.
  root to: "application#spa_fallback"

  # QR público — sin prefijo /api para que los links de QR funcionen siempre
  get "/p/:codigo_qr",   to: "public/plantas#show_qr",   defaults: { format: :json }
  get "/s/:codigo_qr",   to: "public/stocks#show_qr",    defaults: { format: :json }
  get "/c/:token",       to: "public/carnets#show",      defaults: { format: :json }
  # OJO: los datos del pasaporte de dispensa van bajo /api (ver scope abajo), NO a
  # nivel root. A nivel root colisionarían con la navegación del browser a la página
  # /d/:token de la SPA (mismo origen → el backend interceptaría el HTML).

  # Web pública del club (accedida desde el sitio web externo del club)
  namespace :public, defaults: { format: :json } do
    resource :club, only: [:show], controller: 'club'
    resources :geneticas, only: [:index, :show]
    resources :noticias, only: [:index, :show]
    resources :eventos, only: [:index, :show]
    resources :galeria, only: [:index], controller: 'galeria'
    get '/plantas/:codigo_qr', to: 'plantas#show_qr'
  end

  # Webhooks externos — sin prefijo /api para URLs fijas de hardware
  namespace :webhooks do
    post 'lecturas', to: 'lecturas#create'
  end

  # ══════════════════════════════════════════════════════════════
  # API — todo bajo /api para evitar colisión con Vue Router
  # ══════════════════════════════════════════════════════════════
  scope '/api', defaults: { format: :json } do
    # Pasaporte público de dispensa (datos). La página vive en la SPA en /d/:token y
    # consume estos endpoints. Bajo /api para no chocar con la navegación de la SPA.
    get  'd/:token',     to: 'public/dispensas#preview'
    post 'd/:token/ver', to: 'public/dispensas#ver'

    devise_for :users,
               path: '',
               path_names: { sign_in: 'users/sign_in', sign_out: 'users/sign_out' },
               controllers: { sessions: 'users/sessions' }

    get "/me",             to: "me#show"
    get "/me/movimientos", to: "me#movimientos"
    get "/stats",          to: "stats#show"

    scope '/analytics', controller: :analytics do
      get :rendimiento_genetica
      get :dispensador
      get :produccion
      get :correlacion_ambiental
      get :pl_lotes
      get :ejecutivo
      get :comparativa_salas
      get :contabilidad
    end

    resource :benchmark, only: [:show], controller: :benchmark  # solo super_admin, uso interno de plataforma
    namespace :public do
      resource :benchmark, only: [:show], controller: :benchmark  # público, datos anonimizados y agregados
    end

    post '/asistente/parsear',       to: 'asistente#parsear'
    post '/asistente/ejecutar',      to: 'asistente#ejecutar'
    post '/asistente/consultar',     to: 'asistente#consultar'
    post '/asistente/analizar_lote',      to: 'asistente#analizar_lote'
    get  '/asistente/historial_analisis', to: 'asistente#historial_analisis'

    resources :push_subscriptions, only: [:create, :destroy]
    resources :webhooks do
      resources :webhook_deliveries, only: [:index], shallow: true
    end

    resources :salas do
      resources :lotes, only: [:index, :create]
      resources :cultivadores, controller: 'sala_cultivadores', only: [:index, :create, :destroy]
      resources :notas, only: [:index, :create]
      resources :lecturas_ambientales, only: [:index, :create, :destroy]
      get  :ambiente,    to: 'lecturas_ambientales#ambiente'
      get  :historico,   to: 'lecturas_ambientales#historico'
      post :ai_import,   to: 'lecturas_ambientales/ai_imports#create'
      resources :alertas, only: [:index]
      member do
        post :cargar_lote
        post :cambiar_fase
        post :registrar_sala
      end
    end

    resources :lotes, only: [:index, :show, :update, :destroy, :create] do
      collection do
        get :export_csv
        get :proximo_codigo
        get 'por_qr/:codigo_qr', action: :por_qr
      end
      resource :costo, controller: :costo_lotes, only: [:show, :create, :update] do
        post :recalcular   # recalcula insumos/energía/mano de obra desde el libro contable
      end
      resources :registros_ambientales, only: [:index, :create, :destroy]
      resources :lote_eventos,          only: [:index, :create, :destroy]
      resources :fotos, only: [:index, :create, :destroy], controller: 'fotos_lote'
      resources :notas, only: [:index, :create]
      resources :pesadas, only: [:index, :create, :destroy]
      resources :analisis_laboratorio, only: [:index, :create, :update, :destroy]
      resources :pesajes_manicura, only: [:index, :show, :create, :destroy] do
        member do
          post :enviar
          post :confirmar
          post :reabrir
        end
      end
      member do
        post  :transiciones
        post  :cerrar_curado
        post  :avanzar_fase
        post  :cosechar_plantas
        post  :asignar_manicurador
        patch :completar_datos
        get   :timeline
        get   :preview_plan
        post  :aplicar_plan
        get   :pl
      end
    end

    get '/pesajes_manicura', to: 'pesajes_manicura#index_admin'

    get '/stocks/qr/:codigo_qr', to: 'stocks#show_by_qr'
    resources :stocks, only: [:index, :show, :create, :update, :destroy] do
      member do
        post :asignar
        get  :trazabilidad
        post :ajuste
        post :descartar
        get  :movimientos
      end
    end

    resources :plants do
      member do
        post   :add_foto
        post   :registrar_peso
        delete 'fotos/:blob_id', to: 'plants#remove_foto', as: :remove_foto
      end
      resources :plant_activities, only: [:index, :create, :destroy]
      resources :notas, only: [:index, :create]
    end

    resources :notas, only: [:destroy]

    resources :pacientes do
      collection do
        get :export_csv
        get :criticos
      end
      resources :notas,        controller: "paciente_notas",    only: [:index, :create]
      resources :indicaciones, controller: "indicacion_medica", only: [:index, :create]
      resources :dispensaciones, only: [:index, :create]
      resources :reservas, only: [:index, :create]
      resources :reprocann_renovaciones, only: [:index, :create, :update, :destroy]
      resources :turnos, controller: "paciente_turnos", only: [:index]
      resources :documents, controller: 'patient_documents' do
        member do
          post  :firmar
          patch :archivar
        end
      end
      resource :cuenta_corriente, controller: 'cuenta_corrientes', only: [:show] do
        collection do
          post  :cargar
          post  :ajuste
          post  :registrar_pago
          patch :set_limite
          patch :toggle_gramos
          patch :set_limite_g
          post  :cargar_g
        end
      end
      member do
        get    :timeline
        post   :subir_reprocann
        delete :eliminar_reprocann
        post   :enviar_mail
        get    :mails_enviados
      end
    end
    resources :paciente_notas, only: [:destroy]

    # Alias deprecado — mantenido por compatibilidad
    resources :socios, controller: 'pacientes', as: :socios_legacy do
      resources :notas,        controller: "paciente_notas",    only: [:index, :create]
      resources :indicaciones, controller: "indicacion_medica", only: [:index, :create]
      resources :dispensaciones, only: [:index, :create]
      resources :documents, controller: 'patient_documents' do
        member do
          post  :firmar
          patch :archivar
        end
      end
    end
    resources :socio_notas, controller: 'paciente_notas', only: [:destroy], as: :socio_notas_legacy

    get '/indicaciones_medicas', to: 'indicacion_medica#index_medico'

    # Médico — ficha clínica + turnos
    namespace :medico do
      resources :pacientes, only: [:index] do
        member { get :ficha }
      end
      resources :turnos, only: [:index, :create, :update, :destroy]
      resources :check_ins, only: [:create]
      resource  :disponibilidad, only: [:index, :update], controller: 'disponibilidad'
    end

    namespace :admin do
      resources :medicos, only: [:index] do
        member do
          get  :disponibilidad
          get  :turnos
          post :crear_turno
        end
      end
      resources :turnos, only: [:update, :destroy]
    end
    resources :indicaciones, controller: "indicacion_medica", only: [:show, :update, :destroy] do
      member { get :prescripcion_pdf }
    end
    resources :dispensaciones, only: [:index, :show, :update, :destroy] do
      collection do
        get  :mis_paquetes
        get  :export_csv
        patch :iniciar_viaje
      end
      member do
        patch :entregar
        patch :reportar_fallo
        patch :reprogramar
        patch :cancelar_entrega
      end
    end

    resources :reservas, only: [:index, :show, :update, :destroy] do
      member do
        patch :entregar
        patch :cancelar
      end
    end

    resources :geneticas do
      member do
        delete 'fotos/:foto_id', to: 'geneticas#destroy_foto', as: :foto
      end
    end
    resources :noticias
    resources :eventos

    resource :profile, only: [:show, :update], controller: "profile" do
      patch :password
      patch :avatar
    end

    resource :preferences, only: [:show, :update], controller: "preferences" do
      post   :upload_logo,    on: :collection
      post   :test_smtp,      on: :collection
      patch  :update_twilio,  on: :collection
      delete :destroy_twilio, on: :collection
      post   :test_twilio,    on: :collection
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
        get    :stats
      end
    end

    resources :document_templates

    resources :ariccame_registros, only: [:index, :show]

    resource :plan, only: [:show], controller: 'plan'
    resources :documentos, only: [:index, :show, :create, :update, :destroy] do
      member do
        post  :subir_archivo
        get   :descargar
      end
    end

    resources :alertas_internas, only: [:index] do
      member do
        patch :marcar_leida
      end
      collection do
        patch :marcar_todas_leidas
      end
    end

    scope '/informes', controller: :informes do
      get :reprocann
      get :produccion
      get :dispensaciones,  action: :dispensaciones
      get :sedes,           action: :sedes
      get :cumplimiento
      get :plan_vs_real
    end

    resources :sedes do
      resources :stocks, only: [:index]
    end

    resources :movimientos_contables, only: [:index, :show, :create, :update, :destroy] do
      collection do
        get :dashboard
        get :export_csv
        post :cerrar_periodo    # congela movimientos hasta una fecha (solo admin)
        post :reabrir_periodo   # retrocede/levanta el cierre (solo admin, auditado)
      end
    end

    resource :informe_semestral, only: [:show], controller: :informe_semestral

    get 'historial', to: 'historial#index'

    # Plan de Trabajo
    resources :plan_trabajos do
      collection do
        get  :activo
        post :interpretar_archivo
      end
      member do
        post :publicar
        post :archivar
        get  :export_csv
      end
    end
    scope '/plan_trabajos/:id', controller: :plan_trabajos do
      get    'plan_tareas',       action: :plan_tareas_index
      post   'plan_tareas',       action: :plan_tareas_create
      patch  'plan_tareas/:tid',  action: :plan_tareas_update
      delete 'plan_tareas/:tid',  action: :plan_tareas_destroy
    end

    # Aplicación de plantillas de plan
    resources :aplicacion_planes, only: [:index, :create, :show, :destroy] do
      member { post :cancelar }
    end

    resources :jornadas, only: [:index, :create, :update, :destroy]

    resources :tareas do
      collection do
        get  :dashboard
        get  :semana
        post :completar_masivo
      end
      member do
        post   :iniciar
        post   :completar
        post   :cancelar
        delete :cancelar_serie
      end
    end

    resources :dispositivos do
      resources :imports, only: [:create], module: :lecturas_ambientales
      member do
        post :regenerar_token
      end
    end

    resources :setpoints_fase,    only: [:index, :show, :create, :update, :destroy]
    resources :reglas_ambientales, only: [:index, :show, :create, :update, :destroy]
    resources :alertas, only: [:index, :show] do
      member do
        post :reconocer
        post :resolver
      end
    end

    namespace :super_admin do
      resources :clubs, only: [:index, :show, :create, :update, :destroy] do
        member do
          post   :crear_usuarios_default
          patch  :cambiar_plan
          post   :observar
          delete :detener_observacion
          patch  :restaurar
        end
      end
      resources :users, only: [:index, :create, :update, :destroy]
      get :stats,    to: 'stats#show'
      get :metricas, to: 'stats#metricas'
    end
  end

  begin
    require 'sidekiq/web'
    Sidekiq::Web.use(Rack::Auth::Basic) do |user, pass|
      ActiveSupport::SecurityUtils.secure_compare(
        ::Digest::SHA256.hexdigest(pass),
        ::Digest::SHA256.hexdigest(ENV.fetch('SIDEKIQ_PASSWORD', 'changeme'))
      ) && user == 'admin'
    end if Rails.env.production?
    mount Sidekiq::Web, at: '/sidekiq'
  rescue LoadError
    Rails.logger.warn 'sidekiq/web not available — /sidekiq not mounted'
  end

  # SPA fallback — sirve index.html para cualquier ruta desconocida con Accept: text/html
  # Esto permite navegación directa a rutas del frontend en producción
  get '*path', to: 'application#spa_fallback', constraints: ->(req) { !req.xhr? && req.format.html? }
end
