class AriccameRegistrosController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!

  def index
    scope = current_user.club.ariccame_registros.order(created_at: :desc)

    scope = scope.where(estado: params[:estado]) if params[:estado].present?
    scope = scope.where(tipo:   params[:tipo])   if params[:tipo].present?

    page  = (params[:pagina] || 1).to_i
    limit = (params[:limite] || 30).to_i
    total = scope.count

    registros = scope.offset((page - 1) * limit).limit(limit)

    render json: {
      data: registros.map { |r| serialize(r) },
      meta: {
        total:      total,
        pagina:     page,
        limite:     limit,
        pendientes: current_user.club.ariccame_registros.pendientes.count,
        con_error:  current_user.club.ariccame_registros.con_error.count,
      }
    }
  end

  def show
    registro = current_user.club.ariccame_registros.find(params[:id])
    render json: { data: serialize(registro) }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Registro no encontrado' }, status: :not_found
  end

  # POST /ariccame_registros/:id/reenviar — transmite (o reintenta) un registro.
  def reenviar
    registro = current_user.club.ariccame_registros.find(params[:id])
    res = Ariccame::Transmisor.call(registro)
    if res.ok?
      render json: { data: serialize(registro.reload) }
    else
      render json: { error: res.error, data: serialize(registro.reload) }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Registro no encontrado' }, status: :not_found
  end

  # POST /ariccame_registros/transmitir_pendientes — transmite todos los pendientes
  # y los errores reintentables de una.
  def transmitir_pendientes
    registros = current_user.club.ariccame_registros
                            .where(estado: %w[pendiente error])
                            .where('intentos < ?', Ariccame::Transmisor::MAX_INTENTOS)
    ok = 0
    err = 0
    registros.find_each do |r|
      Ariccame::Transmisor.call(r).ok? ? (ok += 1) : (err += 1)
    end
    render json: { confirmados: ok, con_error: err, total: ok + err }
  end

  private

  def require_admin!
    unless current_user.admin?
      render json: { error: 'No autorizado' }, status: :forbidden
    end
  end

  def serialize(r)
    {
      id:               r.id,
      tipo:             r.tipo,
      estado:           r.estado,
      codigo_ariccame:  r.codigo_ariccame,
      error_mensaje:    r.error_mensaje,
      intentos:         r.intentos,
      enviado_at:       r.enviado_at,
      confirmado_at:    r.confirmado_at,
      stock_id:         r.stock_id,
      dispensacion_id:  r.dispensacion_id,
      payload:          r.payload,
      respuesta:        r.respuesta,
      created_at:       r.created_at,
    }
  end
end
