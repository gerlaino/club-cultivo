# Aplana el catálogo contable: SECTOR → CATEGORÍA, sin el escalón intermedio.
#
# El catálogo tenía dos niveles (Insumos › Fertilizante). Había que entender el escalón antes de
# poder anotar un gasto, y media app trataba a las subcategorías como categorías.
#
# NO se borran las subcategorías: se PROMUEVEN. Los nombres útiles son justo las hojas
# —"Fertilizante", "Electricidad", "Sueldos"— y borrarlas dejaría al club con "Insumos" y
# "Servicios", que no clasifican nada. Cada sub sube a nivel raíz con el sector y el destino de
# stock que heredaba de su madre, y se lleva sus movimientos intactos.
#
# Después se retiran las madres genéricas que quedaron sin nada: sin subcategorías, sin
# movimientos y sin insumos. Las que sí tienen movimientos se quedan: son una categoría más.
#
#   bundle exec rake categorias:aplanar SIMULAR=1   # mirar qué haría
#   bundle exec rake categorias:aplanar             # hacerlo
#   bundle exec rake categorias:aplanar CLUB_ID=4   # una sola organización
namespace :categorias do
  desc 'Sube las subcategorías a categorías y retira las madres genéricas que quedan vacías'
  task aplanar: :environment do
    simular = ENV['SIMULAR'].present?
    clubes  = ENV['CLUB_ID'].present? ? Club.where(id: ENV['CLUB_ID']) : Club.all

    puts simular ? '— SIMULACRO: no se escribe nada —' : '— Ejecutando —'

    promovidas = 0
    retiradas  = 0

    clubes.find_each do |club|
      ActsAsTenant.with_tenant(club) do
        subs = CategoriaContable.where.not(parent_id: nil).includes(:parent).to_a
        next if subs.empty?

        puts "\n#{club.name} (##{club.id})"

        madres = subs.filter_map(&:parent).uniq

        subs.each do |sub|
          madre = sub.parent
          movs  = MovimientoContable.where(categoria_contable_id: sub.id).count
          puts "  ↑ #{madre&.nombre} › #{sub.nombre} → categoría de " \
               "#{(sub.unidad_efectiva || madre&.unidad_efectiva)&.nombre || 'sin sector'} " \
               "(#{movs} movimientos)"

          promovidas += 1
          next if simular

          # Se queda con lo que heredaba: sin esto, al soltar la madre pierde el sector y el
          # destino de stock, y todos sus movimientos futuros caen en "Sin sector".
          sub.update!(
            parent_id:      nil,
            unidad_negocio: sub.unidad_negocio || madre&.unidad_negocio,
            comportamiento: sub.comportamiento == 'general' ? (madre&.comportamiento || 'general') : sub.comportamiento,
          )
        end

        madres.each do |madre|
          madre.reload
          # En el simulacro las subs siguen colgando (no se tocó nada), así que se las ignora:
          # si no, el simulacro informaría "se queda" para TODAS y no predeciría nada.
          sin_hijas = simular || madre.subcategorias.empty?
          vacia = sin_hijas &&
                  MovimientoContable.where(categoria_contable_id: madre.id).none? &&
                  Insumo.where(categoria_contable_id: madre.id).none?

          if vacia
            puts "  × #{madre.nombre} — se retira (quedó sin nada colgando)"
            retiradas += 1
            madre.destroy unless simular
          else
            puts "  = #{madre.nombre} — se queda: tiene movimientos propios"
          end
        end
      end
    end

    puts "\n#{simular ? 'Se promoverían' : 'Promovidas'}: #{promovidas} subcategorías"
    puts "#{simular ? 'Se retirarían' : 'Retiradas'}:   #{retiradas} categorías vacías"
    puts '(SIMULAR=1 no escribió nada)' if simular
  end
end
