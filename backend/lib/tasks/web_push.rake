namespace :web_push do
  desc "Genera un par de claves VAPID para Web Push. Van en el entorno del backend (web y worker)"
  task generate_keys: :environment do
    require 'web-push'
    keys = WebPush.generate_key

    puts ""
    puts "══════════════════════════════════════════════════════"
    puts "  VAPID Keys — al entorno del backend (web service Y worker, el mismo par)"
    puts "══════════════════════════════════════════════════════"
    puts ""
    puts "    VAPID_PUBLIC_KEY=#{keys.public_key}"
    puts "    VAPID_PRIVATE_KEY=#{keys.private_key}"
    puts "    VAPID_EMAIL=<un mail de contacto>"
    puts ""
    puts "  El frontend NO lleva nada: la clave pública viaja en /me."
    puts "  Cambiar el par invalida las suscripciones existentes: cada dispositivo se vuelve a"
    puts "  suscribir al tocar «Activar notificaciones»."
    puts "══════════════════════════════════════════════════════"
    puts ""
  end
end
