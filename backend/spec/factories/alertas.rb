FactoryBot.define do
  factory :alerta do
    # sala y regla deben compartir club. Con acts_as_tenant el club es inmutable una
    # vez persistido, así que se arma desde el principio (no se reasigna en after-build).
    transient do
      club { association(:club) }
    end

    sala    { association(:sala, club: club) }
    regla   { association(:regla_ambiental, club: club) }
    club_id { club.id }
    estado  { 'activa' }
    mensaje { 'Temperatura fuera de rango' }
  end
end
