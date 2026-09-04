# AUDITORÍA CONTABLE — SÓLO LEE, NO TOCA NADA.
#
# Un descuadre de stock se delata solo: alguien pesa el frasco y el número no da. La plata no
# tiene eso. Un asiento duplicado sube el resultado del mes y parece que se vendió más; un saldo
# de cuenta corriente que se despegó de su historial sólo se descubre cuando el paciente reclama.
# No falta una fila ni sobra un movimiento: el total simplemente cambió, y no hay nada que mirar.
#
# Esto es lo que hay que mirar. Corre sobre los datos reales y lista lo que no cierra, con el id
# de cada caso para poder ir a verlo. No arregla: decidir qué hacer con un descuadre es de una
# persona, y arreglarlo a ciegas es cómo se tapa el problema que lo causó.
#
#   bundle exec rake contabilidad:auditar            # todas las organizaciones
#   bundle exec rake contabilidad:auditar CLUB=slug  # una sola
#   bundle exec rake contabilidad:auditar DETALLE=1  # lista cada caso, no sólo el conteo
require Rails.root.join('lib/auditoria_contable')

namespace :contabilidad do
  desc 'Audita saldos, asientos y cobros buscando descuadres (sólo lectura)'
  task auditar: :environment do
    clubes = if ENV['CLUB'].present?
               Club.where(slug: ENV['CLUB'])
             else
               Club.all
             end
    abort "No encontré la organización #{ENV['CLUB']}" if clubes.empty?

    detalle  = ENV['DETALLE'].present?
    hallazgos = 0

    clubes.find_each do |club|
      ActsAsTenant.with_tenant(club) do
        puts "\n#{'═' * 72}"
        puts "#{club.name} (##{club.id})"
        puts '═' * 72

        hallazgos += AuditoriaContable.new(club, detalle: detalle).call
      end
    end

    puts "\n#{'─' * 72}"
    if hallazgos.zero?
      puts 'Todo cierra. Ningún descuadre.'
    else
      puts "#{hallazgos} cosa#{'s' if hallazgos != 1} para mirar."
      puts 'Ninguna se arregló sola: cada una necesita que alguien decida qué pasó.'
    end
  end
end

