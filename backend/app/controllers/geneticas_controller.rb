class GeneticasController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin_for_write!, only: [:create, :update, :destroy, :destroy_foto]
  before_action :set_genetica, only: [:show, :update, :destroy, :destroy_foto]

  # GET /geneticas
  # Params opcionales:
  #   solo_club=true  → solo genéticas del club actual (para selects internos)
  #   disponible=true → además filtra disponible: true
  def index
    club = current_user.club

    scope = if params[:solo_club].present?
      Genetica.where(club_id: club.id)
    else
      base = Genetica.where(global: true, registrada_inase: true)
      club ? base.or(Genetica.where(club_id: club.id)) : base
    end

    scope = scope.where(activa: true)
    scope = scope.where(disponible: true) if params[:disponible].present?
    geneticas = scope.order(nombre: :asc)
    render json: geneticas.map { |g| serialize_genetica(g, club) }
  end

  # GET /geneticas/:id
  def show
    render json: serialize_genetica_detail(@genetica)
  end

  # POST /geneticas
  def create
    genetica = Genetica.new(genetica_params)
    is_global = current_user.super_admin? && params[:genetica][:global].present?
    genetica.global   = is_global
    genetica.club_id  = is_global ? nil : current_user.club_id
    if genetica.save
      attach_foto(genetica) if params[:foto].present?
      render json: serialize_genetica(genetica, current_user.club), status: :created
    else
      render json: { errors: genetica.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /geneticas/:id
  def update
    # Campos protegidos para genéticas INASE (vienen con info previa, incl. los días por fase)
    permitted = if @genetica.registrada_inase?
                  genetica_params.except(:nombre, :tipo, :thc, :cbd, :criador, :registrada_inase,
                                         :tiempo_floracion, :dias_vegetativo_objetivo, :dias_cosecha_objetivo)
                else
                  genetica_params
                end

    if @genetica.update(permitted)
      attach_foto(@genetica) if params[:foto].present?
      render json: serialize_genetica(@genetica, current_user.club)
    else
      render json: { errors: @genetica.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /geneticas/:id/fotos/:foto_id
  def destroy_foto
    foto = @genetica.fotos.find { |f| f.id.to_s == params[:foto_id].to_s }
    return render json: { error: 'Foto no encontrada' }, status: :not_found unless foto
    foto.purge
    head :no_content
  end

  # DELETE /geneticas/:id → soft delete, bloqueado para INASE
  def destroy
    if @genetica.registrada_inase?
      return render json: { error: 'Las genéticas registradas en INASE no pueden eliminarse' }, status: :forbidden
    end
    @genetica.update(activa: false)
    head :no_content
  end

  private

  def set_genetica
    club = current_user.club
    scope = Genetica.where(global: true, registrada_inase: true)
    scope = scope.or(Genetica.where(club_id: club.id)) if club
    @genetica = scope.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Genética no encontrada' }, status: :not_found
  end

  def attach_foto(genetica)
    genetica.fotos.attach(params[:foto])
  rescue => e
    Rails.logger.warn "Error adjuntando foto: #{e.message}"
  end

  def plantas_count(genetica, club)
    return 0 unless club
    Plant.joins(:lote)
         .where(lotes: { club_id: club.id, genetica_id: genetica.id })
         .where.not(plants: { state: %w[cosechado descartada] })
         .count
  end

  def foto_url(genetica)
    return nil unless genetica.fotos.attached?
    url_for(genetica.fotos.first)
  rescue
    nil
  end

  def genetica_params
    params.require(:genetica).permit(
      :nombre, :tipo, :thc, :cbd, :descripcion, :consejos_club,
      :origen, :tiempo_floracion, :dias_vegetativo_objetivo, :dias_cosecha_objetivo, :rendimiento,
      :altura, :dificultad, :activa, :disponible,
      :registrada_inase, :numero_registro_inase, :fecha_registro_inase, :categoria_inase,
      :criador, :terpenos, :visible_web
    )
  end

  def serialize_genetica(genetica, club)
    {
      id:                     genetica.id,
      club_id:                genetica.club_id,
      global:                 genetica.global,
      nombre:                 genetica.nombre,
      slug:                   genetica.slug,
      tipo:                   genetica.tipo,
      thc:                    genetica.thc,
      cbd:                    genetica.cbd,
      dificultad:             genetica.dificultad,
      disponible:             genetica.disponible,
      activa:                 genetica.activa,
      registrada_inase:       genetica.registrada_inase,
      numero_registro_inase:  genetica.numero_registro_inase,
      fecha_registro_inase:   genetica.fecha_registro_inase,
      categoria_inase:        genetica.categoria_inase,
      criador:                genetica.criador,
      terpenos:               genetica.terpenos,
      visible_web:            genetica.visible_web,
      foto_url:               foto_url(genetica),
      plantas_count:          plantas_count(genetica, club),
    }
  end

  def serialize_genetica_detail(genetica)
    club  = current_user.club
    lotes = genetica.lotes.where(club_id: club&.id)
                    .includes(:sala, :costo_lote)
                    .order(start_date: :desc)
                    .limit(50)

    lote_ids = lotes.map(&:id)

    # Peso seco y fecha de cosecha — bulk para evitar N+1
    peso_por_lote = Plant.where(lote_id: lote_ids)
                         .where.not(peso_seco: nil)
                         .group(:lote_id)
                         .pluck(
                           Arel.sql('lote_id, SUM(peso_seco), MAX(fecha_cosecha)')
                         )
                         .each_with_object({}) { |(lid, peso, fecha), h| h[lid] = { peso: peso.to_f, fecha: fecha } }

    # Ingresos por lote — 1 query
    ingresos_por_lote = Dispensacion
      .joins(:stock)
      .where(stocks: { lote_id: lote_ids })
      .group('stocks.lote_id')
      .sum('dispensaciones.cantidad * COALESCE(dispensaciones.precio_unitario_ars, 0)')

    lotes_data = lotes.map do |l|
      pdata    = peso_por_lote[l.id] || {}
      peso     = pdata[:peso].to_f
      ingresos = ingresos_por_lote[l.id].to_f.round(2)
      costo    = l.costo_lote&.costo_total.to_f
      margen   = (ingresos - costo).round(2)
      rend     = l.rendimiento_real_g&.to_f
      obj      = l.rendimiento_objetivo_g&.to_f
      desv_pct = rend && obj && obj > 0 ? ((rend - obj) / obj * 100).round(1) : nil

      {
        id:              l.id,
        codigo:          l.codigo,
        estado:          l.estado,
        start_date:      l.start_date,
        fecha_cosecha:   pdata[:fecha],
        sala:            l.sala&.nombre,
        plants_count:    l.plants_count,
        peso_seco_total: peso.positive? ? peso.round(2) : nil,
        rendimiento_gramos_planta: (peso.positive? && l.plants_count.to_i > 0) ? (peso / l.plants_count).round(1) : nil,
        rendimiento_real_g:  rend,
        rendimiento_obj_g:   obj,
        desv_pct:,
        ingresos:        ingresos > 0 ? ingresos : nil,
        costo_total:     l.costo_lote ? costo.round(2) : nil,
        margen:          (ingresos > 0 || costo > 0) ? margen : nil,
        margen_pct:      ingresos > 0 ? (margen / ingresos * 100).round(1) : nil,
      }
    end

    # P&L resumen de la genética
    con_ingresos = lotes_data.select { |l| l[:ingresos] }
    con_pl       = lotes_data.select { |l| l[:margen] }
    con_margen_pct = lotes_data.filter_map { |l| l[:margen_pct] }
    con_rend = lotes_data.filter_map { |l| l[:rendimiento_real_g] }

    pl_resumen = {
      lotes_con_datos:       con_pl.size,
      ingresos_promedio:     con_ingresos.any? ? (con_ingresos.sum { |l| l[:ingresos] } / con_ingresos.size).round(2) : nil,
      costo_promedio:        con_pl.any? ? (con_pl.sum { |l| l[:costo_total].to_f } / con_pl.size).round(2) : nil,
      margen_promedio:       con_pl.any? ? (con_pl.sum { |l| l[:margen] } / con_pl.size).round(2) : nil,
      margen_pct_promedio:   con_margen_pct.any? ? (con_margen_pct.sum / con_margen_pct.size).round(1) : nil,
      rend_promedio_g:       con_rend.any? ? (con_rend.sum / con_rend.size).round(1) : nil,
    }

    {
      id:                     genetica.id,
      club_id:                genetica.club_id,
      global:                 genetica.global,
      nombre:                 genetica.nombre,
      slug:                   genetica.slug,
      tipo:                   genetica.tipo,
      thc:                    genetica.thc,
      cbd:                    genetica.cbd,
      descripcion:            genetica.descripcion,
      consejos_club:          genetica.consejos_club,
      origen:                 genetica.origen,
      tiempo_floracion:       genetica.tiempo_floracion,
      dias_vegetativo_objetivo: genetica.dias_vegetativo_objetivo,
      dias_cosecha_objetivo:    genetica.dias_cosecha_objetivo,
      rendimiento:            genetica.rendimiento,
      altura:                 genetica.altura,
      dificultad:             genetica.dificultad,
      disponible:             genetica.disponible,
      activa:                 genetica.activa,
      registrada_inase:       genetica.registrada_inase,
      numero_registro_inase:  genetica.numero_registro_inase,
      fecha_registro_inase:   genetica.fecha_registro_inase,
      categoria_inase:        genetica.categoria_inase,
      criador:                genetica.criador,
      terpenos:               genetica.terpenos,
      visible_web:            genetica.visible_web,
      fotos:            genetica.fotos.attached? ? genetica.fotos.map { |f| { id: f.id, url: url_for(f) } } : [],
      plantas_count:    plantas_count(genetica, club),
      lotes_historicos: lotes_data,
      pl_resumen:,
      created_at:       genetica.created_at,
      updated_at:       genetica.updated_at,
    }
  end
end