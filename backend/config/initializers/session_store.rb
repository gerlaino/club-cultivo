# config/initializers/session_store.rb
if Rails.env.production?
  # Staging/Prod (HTTPS y cross-site)
  Rails.application.config.session_store :cookie_store,
                                         key: "_club_session",
                                         same_site: :none,   # obligatorio para cross-site
                                         secure: true,       # obligatorio cuando SameSite=None
                                         domain: :all,
                                         partitioned: true 
else
  # Desarrollo local (HTTP)
  Rails.application.config.session_store :cookie_store,
                                         key: "_club_session",
                                         same_site: :lax,    # localhost:5173 ⇄ 3001 es same-site
                                         secure: false       # si es true, Chrome descarta la cookie en HTTP
end

