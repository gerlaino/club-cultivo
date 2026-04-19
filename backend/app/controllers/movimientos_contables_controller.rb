# backend/app/controllers/movimientos_contables_controller.rb
class MovimientosContablesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin_or_tesorero
  before_action :set_movimiento, only: [:show, :update, :destroy]

  # GET /movimientos_contables
  # Params opcionales: desde, hasta, tipo, categoria, sede_id, lote_id, page, per_page
  def index
    scope = current_user.club.movimientos_contables
                        .includes(:sede, :lote, :dispensacion, :created_by)
                        .recientes

    scope = scope.where(tipo: params[:tipo])           if params[:tipo].present?
    scope = scope.where(categoria: params[:categoria]) if params[:categoria].present?
    scope = scope.por_sede(params[:sede_id])           if params[:sede_id].present?
    scope = scope.por_lote(params[:lote_id])           if params[:lote_id].present?

    if params[:desde].present? && params[:hasta].present?
      desde = Date.parse(params[:desde]) rescue nil
      hasta = Date.parse(params[:hasta]) rescue nil
      scope = scope.del_periodo(desde, hasta) if desde && hasta
    elsif params[:mes].present?
      fecha = Date.parse("#{params[:mes]}-01") rescue Date.today
      scope = scope.del_mes(fecha)
    end

    # Totales para el período filtrado (antes de paginar)
    totales = calcular_totales(scope)

    # Paginación simple
    per_page = (params[:per_page] || 50).to_i.clamp(1, 200)
    page     = (params[:page] || 1).to_i
    total    = scope.count
    items    = scope.offset((page - 1) * per_page).limit(per_page)

    render json: {
      movimientos: items.map { |m| serialize(m) },
      totales:     totales,
      pagination:  { page: page, per_page: per_page, total: total,
                     total_pages: (total.to_f / per_page).ceil },
    }
  end

  # GET /movimientos_contables/dashboard
  def dashboard
    club  = current_user.club
    hoy   = Date.today
    scope = club.movimientos_contables

    # Filtro por sede si viene el parámetro
    scope = scope.por_sede(params[:sede_id]) if params[:sede_id].present?

    mes_actual  = scope.del_mes(hoy)
    mes_ant     = scope.del_mes(hoy - 1.month)
    anio_actual = scope.del_periodo(hoy.beginning_of_year, hoy)

    # Desglose por sede (siempre, para el breakdown comparativo)
    sedes_del_club = club.sedes.activas.order(:nombre)
    por_sede = sedes_del_club.map do |sede|
      s = club.movimientos_contables.por_sede(sede.id)
      mes = s.del_mes(hoy)
      {
        id:       sede.id,
        nombre:   sede.nombre,
        tipo:     sede.tipo,
        ingresos: mes.ingresos.sum(:monto_ars).to_f,
        egresos:  mes.egresos.sum(:monto_ars).to_f,
        balance:  (mes.ingresos.sum(:monto_ars) - mes.egresos.sum(:monto_ars)).to_f,
        anio: {
          ingresos: s.del_periodo(hoy.beginning_of_year, hoy).ingresos.sum(:monto_ars).to_f,
          egresos:  s.del_periodo(hoy.beginning_of_year, hoy).egresos.sum(:monto_ars).to_f,
          balance:  (s.del_periodo(hoy.beginning_of_year, hoy).ingresos.sum(:monto_ars) -
            s.del_periodo(hoy.beginning_of_year, hoy).egresos.sum(:monto_ars)).to_f,
        }
      }
    end

    # Sin sede asignada
    sin_sede = club.movimientos_contables.where(sede_id: nil)
    mes_sin_sede = sin_sede.del_mes(hoy)
    sin_sede_data = {
      id:       nil,
      nombre:   'Sin sede',
      tipo:     nil,
      ingresos: mes_sin_sede.ingresos.sum(:monto_ars).to_f,
      egresos:  mes_sin_sede.egresos.sum(:monto_ars).to_f,
      balance:  (mes_sin_sede.ingresos.sum(:monto_ars) - mes_sin_sede.egresos.sum(:monto_ars)).to_f,
      anio: {
        ingresos: sin_sede.del_periodo(hoy.beginning_of_year, hoy).ingresos.sum(:monto_ars).to_f,
        egresos:  sin_sede.del_periodo(hoy.beginning_of_year, hoy).egresos.sum(:monto_ars).to_f,
        balance:  (sin_sede.del_periodo(hoy.beginning_of_year, hoy).ingresos.sum(:monto_ars) -
          sin_sede.del_periodo(hoy.beginning_of_year, hoy).egresos.sum(:monto_ars)).to_f,
      }
    }
    por_sede << sin_sede_data if sin_sede_data[:ingresos] > 0 || sin_sede_data[:egresos] > 0

    render json: {
      sede_filtro:  params[:sede_id].presence,
      mes_actual: {
        ingresos:       mes_actual.ingresos.sum(:monto_ars).to_f,
        egresos:        mes_actual.egresos.sum(:monto_ars).to_f,
        balance:        (mes_actual.ingresos.sum(:monto_ars) - mes_actual.egresos.sum(:monto_ars)).to_f,
        por_categoria:  resumen_por_categoria(mes_actual),
      },
      mes_anterior: {
        ingresos: mes_ant.ingresos.sum(:monto_ars).to_f,
        egresos:  mes_ant.egresos.sum(:monto_ars).to_f,
        balance:  (mes_ant.ingresos.sum(:monto_ars) - mes_ant.egresos.sum(:monto_ars)).to_f,
      },
      anio_actual: {
        ingresos: anio_actual.ingresos.sum(:monto_ars).to_f,
        egresos:  anio_actual.egresos.sum(:monto_ars).to_f,
        balance:  (anio_actual.ingresos.sum(:monto_ars) - anio_actual.egresos.sum(:monto_ars)).to_f,
        por_mes:  resumen_por_mes(anio_actual, hoy),
      },
      por_sede:            por_sede,
      ultimos_movimientos: scope.recientes.limit(10).map { |m| serialize(m) },
    }
  end

  # GET /movimientos_contables/:id
  def show
    render json: serialize(@movimiento)
  end

  # POST /movimientos_contables
  def create
    movimiento = current_user.club.movimientos_contables.build(movimiento_params)
    movimiento.created_by = current_user

    if movimiento.save
      render json: serialize(movimiento), status: :created
    else
      render json: { errors: movimiento.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /movimientos_contables/:id
  def update
    if @movimiento.update(movimiento_params)
      render json: serialize(@movimiento)
    else
      render json: { errors: @movimiento.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /movimientos_contables/:id
  def destroy
    @movimiento.destroy
    head :no_content
  end

  # GET /movimientos_contables/export_csv
  def export_csv
    scope = current_user.club.movimientos_contables.recientes

    if params[:desde].present? && params[:hasta].present?
      desde = Date.parse(params[:desde]) rescue nil
      hasta = Date.parse(params[:hasta]) rescue nil
      scope = scope.del_periodo(desde, hasta) if desde && hasta
    end

    csv_data = generate_csv(scope)

    send_data csv_data,
              filename:    "movimientos_contables_#{Date.today}.csv",
              type:        "text/csv; charset=utf-8",
              disposition: "attachment"
  end

  private

  def set_movimiento
    @movimiento = current_user.club.movimientos_contables.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Movimiento no encontrado" }, status: :not_found
  end

  def movimiento_params
    params.require(:movimiento_contable).permit(
      :tipo, :categoria, :descripcion, :monto_ars, :fecha,
      :sede_id, :lote_id, :dispensacion_id,
      :comprobante_numero, :comprobante_tipo, :proveedor,
      :pagado, :medio_pago, :notas
    )
  end

  def require_admin_or_tesorero
    unless current_user.admin? || current_user.role.in?(%w[admin abogado auditor])
      render json: { error: "No autorizado" }, status: :forbidden
    end
  end

  def serialize(m)
    {
      id:                   m.id,
      tipo:                 m.tipo,
      tipo_label:           m.tipo_label,
      categoria:            m.categoria,
      categoria_label:      m.categoria_label,
      descripcion:          m.descripcion,
      monto_ars:            m.monto_ars.to_f,
      fecha:                m.fecha,
      comprobante_numero:   m.comprobante_numero,
      comprobante_tipo:     m.comprobante_tipo,
      proveedor:            m.proveedor,
      pagado:               m.pagado,
      medio_pago:           m.medio_pago,
      notas:                m.notas,
      sede:                 m.sede ? { id: m.sede.id, nombre: m.sede.nombre } : nil,
      lote:                 m.lote ? { id: m.lote.id, codigo: m.lote.codigo } : nil,
      dispensacion_id:      m.dispensacion_id,
      created_by:           m.created_by&.first_name || m.created_by&.email,
      created_at:           m.created_at,
      updated_at:           m.updated_at,
    }
  end

  def calcular_totales(scope)
    {
      ingresos: scope.ingresos.sum(:monto_ars).to_f,
      egresos:  scope.egresos.sum(:monto_ars).to_f,
      balance:  (scope.ingresos.sum(:monto_ars) - scope.egresos.sum(:monto_ars)).to_f,
      count:    scope.count,
    }
  end

  def resumen_por_categoria(scope)
    scope.group(:categoria, :tipo)
         .sum(:monto_ars)
         .map { |(cat, tipo), total| { categoria: cat, tipo: tipo, total: total.to_f } }
         .sort_by { |r| -r[:total] }
  end

  def resumen_por_mes(scope, hoy)
    (1..hoy.month).map do |mes|
      fecha   = Date.new(hoy.year, mes, 1)
      sub     = scope.del_mes(fecha)
      ing     = sub.ingresos.sum(:monto_ars).to_f
      egr     = sub.egresos.sum(:monto_ars).to_f
      { mes: mes, mes_label: I18n.l(fecha, format: "%B"), ingresos: ing, egresos: egr, balance: ing - egr }
    end
  end

  def generate_csv(scope)
    require "csv"
    headers = %w[
      ID Fecha Tipo Categoría Descripción Monto_ARS Sede Lote
      Comprobante_Nro Comprobante_Tipo Proveedor Pagado Medio_Pago Notas Creado_por
    ]
    CSV.generate(col_sep: ";", encoding: "UTF-8") do |csv|
      csv << headers
      scope.each do |m|
        csv << [
          m.id, m.fecha, m.tipo_label, m.categoria_label, m.descripcion,
          m.monto_ars.to_f, m.sede&.nombre, m.lote&.codigo,
          m.comprobante_numero, m.comprobante_tipo, m.proveedor,
          m.pagado ? "Sí" : "No", m.medio_pago, m.notas,
          m.created_by&.first_name || m.created_by&.email,
        ]
      end
    end
  end
end