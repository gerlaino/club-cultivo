Rails.application.config.session_store :cookie_store,
                                       key: "_club_session",
                                       same_site: :none,
                                       secure: true, domain: :all # en dev sin https
