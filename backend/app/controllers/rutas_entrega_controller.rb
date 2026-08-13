class RutasEntregaController < ApplicationController
  before_action :authenticate_user!
  before_action -> { require_feature!(:produccion_dispensa) }
  # Una ruta de reparto es Delivery, no la suite entera. Cuando Delivery pasó a ser un add-on
  # (11-ago) se gateó el ROL pero no los endpoints: con el módulo apagado, un admin —que no
  # depende del rol— seguía armando rutas de un módulo que la organización no tiene contratado.
  before_action -> { require_feature!(:delivery) }
  before_action :require_admin_o_supervisor!, only: [:bloqueo]

  # GET /rutas_entrega?delivery_id=&fecha=
  # Ruta de un repartidor para una fecha (o null si no existe).
  def show
    fecha = parse_fecha(params[:fecha])
    ruta  = current_user.club.rutas_entrega.find_by(delivery_id: params[:delivery_id], fecha: fecha)
    render json: ruta ? serialize_ruta(ruta) : { ruta: nil }
  end

  # POST /rutas_entrega/ordenar
  # body: { delivery_id, fecha?, orden: [dispensacion_id, ...] }
  # Crea/actualiza la ruta del repartidor+fecha y asigna orden a cada despacho.
  def ordenar
    delivery_id = params[:delivery_id]
    return render json: { error: 'Falta delivery_id' }, status: :unprocessable_entity if delivery_id.blank?

    es_staff = current_user.admin? || current_user.supervisor?
    # El repartidor puede ordenar SOLO su propia ruta.
    unless es_staff || delivery_id.to_s == current_user.id.to_s
      return render json: { error: 'Sin permiso' }, status: :forbidden
    end

    fecha = parse_fecha(params[:fecha])
    ids   = Array(params[:orden]).map(&:to_i).uniq
    ruta  = RutaEntrega.para(club: current_user.club, delivery_id: delivery_id, fecha: fecha)

    # Si la ruta está fijada por la organización, el repartidor no puede reordenarla.
    if ruta.bloqueada && !es_staff
      return render json: { error: 'La ruta fue fijada por la organización — no se puede reordenar' }, status: :forbidden
    end

    ActiveRecord::Base.transaction do
      ids.each_with_index do |id, i|
        d = despachos_del_club.find_by(id: id)
        next unless d
        d.update_columns(ruta_entrega_id: ruta.id, orden_entrega: i + 1, delivery_id: delivery_id)
      end
    end

    render json: serialize_ruta(ruta.reload)
  end

  # PATCH /rutas_entrega/:id/bloqueo  body: { bloqueada }
  def bloqueo
    ruta = current_user.club.rutas_entrega.find(params[:id])
    ruta.update!(bloqueada: ActiveModel::Type::Boolean.new.cast(params[:bloqueada]))
    render json: serialize_ruta(ruta)
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Ruta no encontrada' }, status: :not_found
  end

  private

  def despachos_del_club
    Dispensacion.joins(stock: :sede).where(sedes: { club_id: current_user.club_id })
  end

  def parse_fecha(val)
    Date.parse(val.to_s)
  rescue ArgumentError, TypeError
    Date.current
  end

  def serialize_ruta(ruta)
    {
      id:           ruta.id,
      delivery_id:  ruta.delivery_id,
      fecha:        ruta.fecha,
      bloqueada:    ruta.bloqueada,
      despachos:    ruta.dispensaciones.order(Arel.sql('orden_entrega NULLS LAST, created_at')).pluck(:id),
    }
  end

  def require_admin_o_supervisor!
    return if current_user&.admin? || current_user&.supervisor?
    render json: { error: 'Solo admin o supervisor' }, status: :forbidden
  end
end
