Rails.application.config.session_store :cookie_store,
                                       key: "_club_session",
                                       same_site: :lax,
                                       secure: false # en dev sin https
