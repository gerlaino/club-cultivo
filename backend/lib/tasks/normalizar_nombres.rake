# Corrige la capitalización de nombres y apellidos que dejan las cargas masivas.
# La lógica vive en `Pacientes::NormalizarNombre` (con specs); acá sólo está el recorrido.
namespace :pacientes do
  desc 'Normaliza mayúsculas/minúsculas de nombre y apellido (SIMULAR=1 reporta sin escribir; CLUB_ID acota)'
  task normalizar_nombres: :environment do
    simular = ENV['SIMULAR'].present?

    ActsAsTenant.without_tenant do
      alcance = Paciente.unscoped.where(deleted_at: nil)
      alcance = alcance.where(club_id: ENV['CLUB_ID']) if ENV['CLUB_ID'].present?

      puts "Alcance : #{ENV['CLUB_ID'].present? ? "organización ##{ENV['CLUB_ID']}" : 'TODAS las organizaciones'}"
      puts "Modo    : #{simular ? 'SIMULACRO (no escribe)' : 'REAL'}"
      puts '-' * 70

      cambian = 0
      intactos = 0

      alcance.find_each do |p|
        nombre   = Pacientes::NormalizarNombre.call(p.nombre)
        apellido = Pacientes::NormalizarNombre.call(p.apellido)

        if nombre == p.nombre && apellido == p.apellido
          intactos += 1
          next
        end

        cambian += 1
        puts format('  %-34s → %s', "#{p.nombre} #{p.apellido}", "#{nombre} #{apellido}")
        next if simular

        # `update_columns` a propósito: es una corrección de formato, no un hecho del negocio.
        # Pasar por `save` dispararía el audit log y llenaría el historial de cada paciente con
        # un "cambió el apellido" que en realidad fue un arreglo de mayúsculas.
        p.update_columns(nombre: nombre, apellido: apellido)
      end

      puts '-' * 70
      puts "Ya estaban bien : #{intactos}"
      puts "#{simular ? 'Cambiarían' : 'Cambiados'}      : #{cambian}"
      puts
      puts 'Simulacro: no se escribió nada. Sacá SIMULAR=1 para aplicarlo.' if simular && cambian.positive?
    end
  end
end
