# EL RESUMEN DE STOCK POR PRODUCTO (12-oct-2026, Germán: «no me convencen los KPIs»).
#
# Las tarjetas sueltas («Flor seca disponible», «Derivados», «Sedes con stock»…) mezclaban
# unidades y preguntas. Esto es una fila por PRODUCTO Y UNIDAD —los gramos nunca se suman con las
# unidades— con las mismas columnas que la tabla de abajo, para que cierre a la vista:
#
#   disponible = en depósito + en mostrador − comprometido (reservas y eventos)
#
# y dos columnas que responden lo que el admin pregunta de verdad:
#   · ALCANZA PARA: días que dura lo disponible al ritmo de lo dispensado en los últimos 28 días
#     (la misma ventana y la misma cuenta que el panel de conducción). nil = no hubo salidas.
#   · ATENCIÓN: lo vencido, lo que vence en 30 días y, para la flor seca, cada sede por debajo
#     del umbral de stock bajo de la organización (el umbral es en gramos de flor).
#
# Mira el inventario de AHORA: no depende de los filtros de fecha ni de forma de la tabla; sí de
# la sede elegida y de las sedes que el usuario puede ver (lo resuelve quien arma `ambito`).
module Stocks
  class ResumenPorProducto
    DIAS_RITMO = 28 # = Panel::Conduccion::DIAS_PROMEDIO
    DIAS_VENCE = 30

    # `ambito`: los stocks que se miran, con o sin cantidad (los agotados también dispensaron).
    def initialize(club:, ambito:, hoy: Time.zone.today)
      @club   = club
      @ambito = ambito
      @hoy    = hoy
    end

    def call
      stocks = @ambito.en_inventario.includes(:sede).to_a
      Stock.precargar_apartados(stocks)
      salidas = dispensado_por_producto
      umbral  = @club.umbral_stock_g.to_d

      stocks.group_by { |s| [s.forma_producto, s.unidad] }.map do |(forma, unidad), grupo|
        deposito    = grupo.sum(0.to_d) { |s| s.en_deposito }
        mostrador   = grupo.sum(0.to_d) { |s| s.apartado_para_mostrador.to_d }
        disponible  = grupo.sum(0.to_d) { |s| s.disponible_para_entregar }
        diario      = salidas[[forma, unidad]].to_d / DIAS_RITMO
        {
          forma: forma, unidad: unidad, stocks: grupo.size,
          en_deposito: deposito.to_f.round(1),
          en_mostrador: mostrador.to_f.round(1),
          comprometido: (deposito + mostrador - disponible).to_f.round(1),
          disponible: disponible.to_f.round(1),
          dispensa_diaria: diario.to_f.round(2),
          alcanza_dias: diario.positive? ? (disponible / diario).floor : nil,
          atencion: atencion(forma, grupo, umbral),
        }
      end.sort_by { |r| [r[:forma] == 'flor_seca' ? 0 : 1, -r[:disponible]] }
    end

    private

    def dispensado_por_producto
      DispensacionItem.joins(:dispensacion, :stock)
                      .merge(Dispensacion.no_canceladas)
                      .where(stock_id: @ambito.select(:id))
                      .where(dispensaciones: { fecha_dispensacion: (@hoy - (DIAS_RITMO - 1))..@hoy })
                      .group('stocks.forma_producto', 'stocks.unidad')
                      .sum('dispensacion_items.cantidad')
    end

    def atencion(forma, grupo, umbral)
      out = []
      vencidos = grupo.count { |s| s.fecha_vencimiento_est && s.fecha_vencimiento_est < @hoy }
      por_vencer = grupo.count { |s| s.fecha_vencimiento_est && (@hoy..(@hoy + DIAS_VENCE)).cover?(s.fecha_vencimiento_est) }
      out << "#{vencidos} vencido#{vencidos == 1 ? '' : 's'}" if vencidos.positive?
      out << "#{por_vencer} vence#{por_vencer == 1 ? '' : 'n'} en #{DIAS_VENCE} días" if por_vencer.positive?
      if forma == 'flor_seca' && umbral.positive?
        grupo.select(&:sede).group_by(&:sede).each do |sede, de_sede|
          disp = de_sede.sum(0.to_d) { |s| s.disponible_para_entregar }
          out << "#{sede.nombre}: debajo del umbral (#{fmt(disp)} g)" if disp < umbral
        end
      end
      out
    end

    def fmt(n) = ActiveSupport::NumberHelper.number_to_delimited(n.to_f.round(1).to_s.sub(/\.0\z/, ''), delimiter: '.', separator: ',')
  end
end
