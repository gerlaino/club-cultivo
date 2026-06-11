namespace :web_push do
  desc "Genera un par de claves VAPID para Web Push. Copiar los valores al .env"
  task generate_keys: :environment do
    require 'web-push'
    keys = WebPush.generate_key

    puts ""
    puts "══════════════════════════════════════════════════════"
    puts "  VAPID Keys — copiar al .env del backend y frontend"
    puts "══════════════════════════════════════════════════════"
    puts ""
    puts "  Backend .env:"
    puts "    VAPID_PUBLIC_KEY=#{keys.public_key}"
    puts "    VAPID_PRIVATE_KEY=#{keys.private_key}"
    puts ""
    puts "  Frontend .env.local:"
    puts "    VITE_VAPID_PUBLIC_KEY=#{keys.public_key}"
    puts ""
    puts "  IMPORTANTE: La clave pública debe ser IDÉNTICA en ambos archivos."
    puts "══════════════════════════════════════════════════════"
    puts ""
  end
end
