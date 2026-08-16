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

  desc 'Borra las categorías precargadas que nadie usó y renombra la "Venta bar" vieja'
  task limpiar_precargadas: :environment do
    simular = ENV['SIMULAR'].present?
    clubes  = ENV['CLUB_ID'].present? ? Club.where(id: ENV['CLUB_ID']) : Club.all

    puts simular ? '— SIMULACRO: no se escribe nada —' : '— Ejecutando —'

    borradas = 0
    con_uso  = 0
    renombradas = 0

    clubes.find_each do |club|
      ActsAsTenant.with_tenant(club) do
        # "Venta bar" es el nombre viejo de la categoría que crea sola la venta del Buffet. Se
        # renombra en vez de borrarse: tiene las ventas colgando.
        vieja = CategoriaContable.find_by(nombre: 'Venta bar')
        if vieja
          nueva = CategoriaContable.where(nombre: 'Venta buffet').where.not(id: vieja.id).first
          if nueva
            # Existen las dos: las ventas viejas pasan a la nueva y la vieja se retira.
            puts "  ~ #{club.name}: 'Venta bar' y 'Venta buffet' conviven — se unifican"
            unless simular
              MovimientoContable.where(categoria_contable_id: vieja.id).update_all(categoria_contable_id: nueva.id, updated_at: Time.current)
              vieja.destroy
            end
          else
            puts "  ~ #{club.name}: 'Venta bar' → 'Venta buffet'"
            vieja.update!(nombre: 'Venta buffet') unless simular
          end
          renombradas += 1
        end

        # Las precargadas: las sembraba la app y no se podían borrar (`es_sistema`). Ahora las
        # categorías las crea el admin. Se van SÓLO las que nadie usó — una con movimientos es
        # historia de la organización, no ruido nuestro.
        CategoriaContable.where(es_sistema: true).find_each do |cat|
          # La de la venta del Buffet la sigue creando el sistema: no se toca. Y "Venta bar" ya
          # pasó por el renombre de arriba — en el simulacro todavía se llama así, por eso se la
          # saltea también: si no, el simulacro la informaría como borrada y no lo va a estar.
          next if ['Venta buffet', 'Venta bar'].include?(cat.nombre)

          usada = MovimientoContable.where(categoria_contable_id: cat.id).exists? ||
                  Insumo.where(categoria_contable_id: cat.id).exists?

          if usada
            puts "  = #{club.name}: \"#{cat.nombre}\" se queda (tiene movimientos)"
            con_uso += 1
          else
            puts "  × #{club.name}: \"#{cat.nombre}\""
            borradas += 1
            cat.destroy unless simular
          end
        end
      end
    end

    puts "\n#{simular ? 'Se borrarían' : 'Borradas'}: #{borradas} categorías precargadas sin uso"
    puts "Se quedan por tener movimientos: #{con_uso}"
    puts "Categorías de venta del Buffet renombradas/unificadas: #{renombradas}"
    puts '(SIMULAR=1 no escribió nada)' if simular
  end
end
