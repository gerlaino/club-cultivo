# Dispensas cuyas líneas NO suman el total.
#
# Hasta el 5-oct-2026, cuando administración pisaba el aporte a mano, el total cambiaba y cada
# línea se quedaba con su precio de lista (cuatro productos que sumaban $171.000 en una dispensa
# de $80.000). La puerta ya está cerrada (`Dispensacion#repartir_en_lineas`). Esto encuentra lo
# que quedó de antes.
#
#   bundle exec rake dispensas:lineas_descuadradas              # sólo lista
#   bundle exec rake dispensas:lineas_descuadradas CLUB=28      # una organización
#   bundle exec rake dispensas:lineas_descuadradas CORREGIR=1   # reparte el total en las líneas
#
# CORREGIR toca SÓLO el precio por unidad de las líneas. El total, los cobros, la cuenta corriente
# y los asientos no se mueven: ésos ya decían lo que entró.
namespace :dispensas do
  desc 'Lista las dispensas cuyas líneas no suman el total (CORREGIR=1 para repartirlo)'
  task lineas_descuadradas: :environment do
    corregir = ENV['CORREGIR'].present?
    club_id  = ENV['CLUB'].presence

    ActsAsTenant.without_tenant do
      scope = Dispensacion.unscoped.where(deleted_at: nil, es_regalo: false)
                          .where.not(medio_pago: 'cambio').where('aporte_socio_ars > 0')
                          .includes(:items)
      scope = scope.joins(:paciente).where(pacientes: { club_id: club_id.to_i }) if club_id

      descuadradas = scope.select do |d|
        d.items.any? && (d.items.sum(&:subtotal_ars) - d.subtotal_productos_ars).abs >= 1
      end
      # Si los GRAMOS de las líneas tampoco dan los de la dispensa, el problema es otro (líneas
      # duplicadas, como en la org demo): repartir el total ahí bajaría los precios a la mitad.
      # Se listan aparte y no se tocan.
      otras, descuadradas = descuadradas.partition { |d| (d.items.sum { |it| it.cantidad.to_d } - d.cantidad.to_d).abs >= 0.001 }
      otras.each { |d| puts format('#%-7d %s  OTRO PROBLEMA: las líneas suman %sg y la dispensa dice %sg — no se toca', d.id, d.fecha_dispensacion, d.items.sum { |it| it.cantidad.to_d }.to_f, d.cantidad.to_f) }

      if descuadradas.empty?
        puts 'Todas las dispensas suman lo que dicen sus líneas.'
        next
      end

      descuadradas.each do |d|
        antes = d.items.sum(&:subtotal_ars)
        puts format('#%-7d %s  líneas $%12.2f  total $%12.2f', d.id, d.fecha_dispensacion, antes, d.subtotal_productos_ars)
        next unless corregir

        Dispensacion.transaction do
          d.repartir_en_lineas(d.subtotal_productos_ars)
          d.items.each { |it| it.update_columns(precio_unitario_ars: it.precio_unitario_ars) }
          d.update_columns(precio_unitario_ars: d.precio_unitario_ars)
        end
      end
      puts "#{descuadradas.size} dispensa(s) #{corregir ? 'corregida(s)' : 'descuadrada(s). CORREGIR=1 para repartir el total en sus líneas'}."
    end
  end
end
