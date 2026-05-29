namespace :seguridad do
  desc "Lista usuarios que aún tienen la contraseña por defecto del club"
  task usuarios_con_password_default: :environment do
    password = ENV.fetch('CLUB_DEFAULT_PASSWORD', '123456Aa')
    puts "Buscando usuarios con password '#{password}'..."
    afectados = []
    User.find_each { |u| afectados << u if u.valid_password?(password) }
    if afectados.empty?
      puts "✓ Ningún usuario tiene la contraseña por defecto."
    else
      puts "⚠ #{afectados.size} usuario(s) con contraseña por defecto:"
      afectados.each { |u| puts "  id=#{u.id} | #{u.email} | #{u.role} | club_id: #{u.club_id}" }
    end
  end
end
