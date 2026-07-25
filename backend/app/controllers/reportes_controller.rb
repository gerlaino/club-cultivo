# Reporte consolidado de Finanzas (Bloque 4): un corte del período con los números que
# el club mira "al día de hoy" — ingresos/egresos/resultado, gastos por categoría,
# aportaciones, dispensado en gramos, cuenta corriente por cobrar y serie para el gráfico.
# Lectura: admin/auditor. Export CSV con rango de fechas.
class ReportesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_lectura

  # GET /finanzas/reporte?desde=YYYY-MM-DD&hasta=YYYY-MM-DD
  def resumen
    club  = current_user.club
    desde = parse_fecha(params[:desde]) || Date.current.beginning_of_month
    hasta = parse_fecha(params[:hasta]) || Date.current
    movs  = club.movimientos_contables.sin_cuotas_futuras.del_periodo(desde, hasta)

    render json: {
      periodo:        { desde: desde, hasta: hasta },
      ingresos:       movs.ingresos.sum(:monto_ars).to_f,
      egresos:        movs.egresos.sum(:monto_ars).to_f,
      resultado:      (movs.ingresos.sum(:monto_ars) - movs.egresos.sum(:monto_ars)).to_f,
      aportaciones:   movs.ingresos.where(categoria: 'aporte_socio').sum(:monto_ars).to_f,
      gastos_por_categoria: gastos_por_categoria(movs),
      por_unidad:     por_unidad(club, movs),
      dispensado_gramos:    dispensado_gramos(club, desde, hasta),
      por_cobrar:     por_cobrar(club),
      serie:          serie_mensual(club, desde, hasta),
    }
  end

  # GET /finanzas/reporte/export?desde=&hasta=  (CSV del período)
  def export_csv
    club  = current_user.club
    desde = parse_fecha(params[:desde]) || Date.current.beginning_of_month
    hasta = parse_fecha(params[:hasta]) || Date.current
    movs  = club.movimientos_contables.includes(:sede, :unidad_negocio, :categoria_contable)
               .sin_cuotas_futuras.del_periodo(desde, hasta).recientes

    require 'csv'
    csv = CSV.generate(col_sep: ';', encoding: 'UTF-8') do |out|
      out << %w[Fecha Tipo Categoría Unidad Descripción Monto_ARS Sede Pagado]
      movs.each do |m|
        out << [
          m.fecha, m.tipo_label, (m.categoria_contable&.nombre || m.categoria_label),
          m.unidad_negocio&.nombre, m.descripcion, m.monto_ars.to_f,
          m.sede&.nombre, (m.pagado ? 'Sí' : 'No')
        ]
      end
    end
    send_data csv, filename: "reporte_#{desde}_#{hasta}.csv", type: 'text/csv; charset=utf-8', disposition: 'attachment'
  end

  private

  def parse_fecha(str)
    return nil if str.blank?

    Date.parse(str)
  rescue Date::Error
    nil
  end

  def gastos_por_categoria(movs)
    movs.egresos.group(:categoria).sum(:monto_ars)
        .map { |cat, total| { categoria: cat, categoria_label: MovimientoContable::CATEGORIA_LABELS[cat] || cat, total: total.to_f } }
        .sort_by { |r| -r[:total] }
  end

  def por_unidad(club, movs)
    unidades = club.unidades_negocio.index_by(&:id)
    movs.group(:unidad_negocio_id, :tipo).sum(:monto_ars).each_with_object({}) do |((uid, tipo), total), acc|
      row = acc[uid] ||= { id: uid, nombre: (uid && unidades[uid]&.nombre) || 'Sin unidad', ingresos: 0.0, egresos: 0.0, balance: 0.0 }
      if %w[ingreso recupero_costo].include?(tipo) then row[:ingresos] += total.to_f
      elsif tipo == 'egreso' then row[:egresos] += total.to_f end
      row[:balance] = (row[:ingresos] - row[:egresos]).round(2)
    end.values.sort_by { |r| -r[:balance] }
  end

  # Gramos dispensados en el período (llega al club vía el paciente).
  def dispensado_gramos(club, desde, hasta)
    Dispensacion.joins(:paciente)
                .where(pacientes: { club_id: club.id })
                .where(fecha_dispensacion: desde..hasta)
                .sum(:cantidad).to_f
  end

  # Deuda real de socios = saldos negativos de cuentas corrientes.
  def por_cobrar(club)
    CuentaCorriente.where(club_id: club.id).where('saldo_disponible < 0').sum('-saldo_disponible').to_f
  end

  # Serie mensual ingresos/egresos/resultado para el gráfico.
  def serie_mensual(club, desde, hasta)
    meses = []
    cursor = desde.beginning_of_month
    while cursor <= hasta
      sub = club.movimientos_contables.sin_cuotas_futuras.del_mes(cursor)
      ing = sub.ingresos.sum(:monto_ars).to_f
      egr = sub.egresos.sum(:monto_ars).to_f
      meses << { mes: cursor.strftime('%Y-%m'), ingresos: ing, egresos: egr, resultado: (ing - egr).round(2) }
      cursor = cursor.next_month
    end
    meses
  end

  def require_lectura
    return if current_user.admin? || current_user.auditor?

    render json: { error: 'No autorizado' }, status: :forbidden
  end
end
