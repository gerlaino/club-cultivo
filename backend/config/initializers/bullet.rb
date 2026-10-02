# Bullet: detecta consultas repetidas (N+1) y precargas que sobran.
#
# - Desarrollo: siempre prendido; avisa en log/development.log y en log/bullet.log.
# - Specs: sólo con BULLET=1 (`BULLET=1 bundle exec rspec spec/requests`), para no ensuciar la
#   corrida normal. Es la auditoría que se corre antes de tocar rendimiento; no rompe ningún spec.
if defined?(Bullet) && (Rails.env.development? || (Rails.env.test? && ENV["BULLET"] == "1"))
  Rails.application.config.after_initialize do
    Bullet.enable        = true
    Bullet.bullet_logger = true
    Bullet.rails_logger  = Rails.env.development?
    Bullet.raise         = false
  end
end
