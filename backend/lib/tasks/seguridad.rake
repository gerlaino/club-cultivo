namespace :seguridad do
  # Este rake es el ÚNICO lugar donde la clave vieja sigue escrita, y tiene que seguir: es el que
  # encuentra a los que quedaron con ella. `Club::PASSWORD_DEFAULT` se eliminó el 20-ago —era una
  # credencial fija en código de producción— pero los usuarios creados ANTES la conservan hasta que
  # entren y la cambien. Correrlo cada tanto y forzar el cambio a los que aparezcan.
  desc "Lista usuarios que aún tienen la contraseña por defecto vieja (PASSWORD=... para probar otra)"
  task usuarios_con_password_default: :environment do
    password = ENV['PASSWORD'].presence || ENV.fetch('CLUB_DEFAULT_PASSWORD', '123456Aa')
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
