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

# CLUB= acepta lo que uno tenga a mano: el slug, el id o un pedazo del nombre. El slug no se lo
# sabe nadie de memoria —"Mitocondria ONG" es `mitocondria_ong`, o `mitocondria`, o vaya a saber—
# y con la shell de producción abierta, fallar por eso es perder el viaje.
def buscar_organizaciones(criterio)
  return Club.order(:id) if criterio.blank?

  criterio = criterio.strip
  por_slug = Club.where(slug: criterio)
  return por_slug if por_slug.exists?

  if criterio.match?(/\A\d+\z/)
    por_id = Club.where(id: criterio)
    return por_id if por_id.exists?
  end

  Club.where('name ILIKE ?', "%#{criterio}%").order(:id)
end

namespace :contabilidad do
  desc 'Audita saldos, asientos y cobros buscando descuadres (sólo lectura)'
  task auditar: :environment do
    clubes = buscar_organizaciones(ENV['CLUB'])
    if clubes.empty?
      # Nadie se acuerda del slug, y "no encontré" a secas obliga a ir a buscarlo a otra pantalla
      # con la shell abierta. Si no está, que al menos diga cuáles hay.
      puts "No encontré ninguna organización que coincida con «#{ENV['CLUB']}». Las que hay:"
      Club.order(:id).each { |c| puts "  #{c.id}  #{c.name}  (slug: #{c.slug})" }
      abort ''
    end

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

