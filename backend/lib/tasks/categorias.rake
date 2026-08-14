# Limpieza del catálogo contable: las subcategorías se eliminan.
#
# El catálogo pasó a tener un solo nivel — SECTOR → CATEGORÍA — porque el tercer escalón había que
# entenderlo antes de poder anotar un gasto y media app trataba a las subcategorías como
# categorías. El alta ya no las crea; esto borra las que quedaron.
#
#   bundle exec rake categorias:eliminar_subcategorias SIMULAR=1   # mirar qué haría
#   bundle exec rake categorias:eliminar_subcategorias             # hacerlo
#   bundle exec rake categorias:eliminar_subcategorias CLUB_ID=4   # una sola organización
namespace :categorias do
  desc 'Elimina las subcategorías: lo que colgaba de ellas pasa a su categoría madre'
  task eliminar_subcategorias: :environment do
    simular = ENV['SIMULAR'].present?
    clubes  = ENV['CLUB_ID'].present? ? Club.where(id: ENV['CLUB_ID']) : Club.all

    puts simular ? '— SIMULACRO: no se toca nada —' : '— Ejecutando —'

    total_subs = 0
    total_movs = 0
    total_ins  = 0

    clubes.find_each do |club|
      ActsAsTenant.with_tenant(club) do
        subs = CategoriaContable.where.not(parent_id: nil).includes(:parent)
        next if subs.empty?

        puts "\n#{club.name} (##{club.id}) — #{subs.count} subcategorías"

        subs.each do |sub|
          madre = sub.parent
          # Sin madre no hay a dónde mover lo que cuelga: se saltea y se avisa. Borrarla dejaría
          # los movimientos sin categoría, que es justo lo que no queremos.
          if madre.nil?
            puts "  ! #{sub.nombre}: sin categoría madre, se deja como está"
            next
          end

          movs = MovimientoContable.where(categoria_contable_id: sub.id)
          ins  = Insumo.where(categoria_contable_id: sub.id)
          n_movs = movs.count
          n_ins  = ins.count

          puts "  #{madre.nombre} › #{sub.nombre} — #{n_movs} movimientos, #{n_ins} insumos"

          unless simular
            # PRIMERO se reasigna y DESPUÉS se borra. Al revés, el `dependent: :nullify` de la
            # asociación deja los movimientos sin categoría y se pierde la clasificación de todo
            # el histórico: el informe por categoría queda con un agujero que no se puede
            # reconstruir. La madre es la clasificación correcta — la sub era un detalle de más.
            movs.update_all(categoria_contable_id: madre.id, updated_at: Time.current)
            ins.update_all(categoria_contable_id: madre.id, updated_at: Time.current)
            sub.destroy
          end

          total_subs += 1
          total_movs += n_movs
          total_ins  += n_ins
        end
      end
    end

    puts "\n#{simular ? 'Se eliminarían' : 'Eliminadas'}: #{total_subs} subcategorías"
    puts "Movimientos reasignados a su madre: #{total_movs}"
    puts "Insumos reasignados a su madre:     #{total_ins}"
    puts '(SIMULAR=1 no escribió nada)' if simular
  end
end
