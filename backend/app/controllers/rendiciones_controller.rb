# La entrega de la recaudación del repartidor: él la inicia, el receptor la cuenta y la recibe.
#
# La plata nunca queda en el aire: el que cuenta es el que la tiene, y ese número entra al cajón.
# Si hubo ajuste, lo que queda pendiente es la CONFORMIDAD del repartidor — constancia, no candado.
class RendicionesController < ApplicationController
  before_action :authenticate_user!
  before_action -> { require_feature!(:delivery) }, only: [:create, :receptores]
  before_action :set_rendicion, only: [:recibir, :conformar]

  # GET /rendiciones — las mías (si soy repartidor) o las que me toca recibir.
  #
  # Administración ve TODAS: es la única forma de responder "¿cuántas veces pasó esto?" sin ir
  # usuario por usuario. El que atiende ve lo suyo y lo que tiene esperando.
  def index
    base = current_user.club.rendiciones_caja.includes(:delivery, :receptor).recientes
    mias = if current_user.delivery?
      base.where(delivery_id: current_user.id)
    elsif %w[admin supervisor super_admin].include?(current_user.role)
      base
    else
      base.where(receptor_id: current_user.id).or(base.pendientes)
    end
    render json: {
      rendiciones: mias.limit(30).map { |r| serialize(r) },
      # Lo que el admin tiene que mirar: se ajustó el monto y el repartidor no dijo si está de
      # acuerdo. No bloquea nada, pero alguien tiene que hablarlo.
      sin_conformar: base.sin_conformar.count,
      # Lo que ESTA persona tiene del club. El repartidor no lo veía en ningún lado: si le
      # anotaron $20.000, tenía que preguntar. Se lo mostramos donde ya mira sus rendiciones.
      mi_saldo_ars: Rendiciones::SaldarACuenta.saldo_de(current_user.club, current_user).to_f,
    }
  end

  # POST /rendiciones/saldar { delivery_id, monto_ars, notas }
  #
  # El repartidor devuelve plata que se había quedado. "Rendir en partes" —entregar hoy la mitad y
  # mañana el resto— es esto: se rinde todo, se recibe lo que trajo y lo que faltó se salda después.
  def saldar
    return render json: { error: 'No autorizado' }, status: :forbidden unless gestiona?

    delivery = current_user.club.users.find_by(id: params[:delivery_id])
    return render json: { error: 'No encontré a esa persona' }, status: :not_found if delivery.nil?

    res = Rendiciones::SaldarACuenta.call(delivery: delivery, club: current_user.club,
                                          receptor: current_user, monto: params[:monto_ars],
                                          notas: params[:notas])
    return render json: { error: res.error }, status: :unprocessable_entity unless res.ok?

    render json: { saldado_ars: res.monto.to_f,
                   saldo_ars: Rendiciones::SaldarACuenta.saldo_de(current_user.club, delivery).to_f }
  end

  # GET /rendiciones/receptores — a quién le puedo rendir
  def receptores
    render json: Rendiciones::Rendir.receptores_de(current_user.club)
                                    .map { |u| { id: u.id, nombre: u.nombre_completo, rol: u.role } }
  end

  # POST /rendiciones { receptor_id } — el repartidor entrega su recaudación
  def create
    return render json: { error: 'No autorizado' }, status: :forbidden unless current_user.delivery?

    receptor = current_user.club.users.find_by(id: params[:receptor_id])
    res = Rendiciones::Rendir.call(delivery: current_user, club: current_user.club, receptor: receptor)
    return render json: { error: res.error }, status: :unprocessable_entity unless res.ok?

    render json: serialize(res.rendicion), status: :created
  end

  # POST /rendiciones/:id/recibir { monto_recibido_ars, motivo }
  def recibir
    res = Rendiciones::Recibir.call(rendicion: @rendicion, receptor: current_user,
                                    monto_recibido: params[:monto_recibido_ars],
                                    motivo: params[:motivo])
    return render json: { error: res.error }, status: :unprocessable_entity unless res.ok?

    render json: serialize(res.rendicion)
  end

  # POST /rendiciones/:id/conformar { conforme, notas }
  def conformar
    conforme = params[:conforme].nil? ? true : ActiveModel::Type::Boolean.new.cast(params[:conforme])
    res = Rendiciones::Conformar.call(rendicion: @rendicion, usuario: current_user,
                                      conforme: conforme, notas: params[:notas])
    return render json: { error: res.error }, status: :unprocessable_entity unless res.ok?

    render json: serialize(res.rendicion)
  end

  private

  def gestiona? = %w[admin supervisor super_admin].include?(current_user.role)

  def set_rendicion
    @rendicion = current_user.club.rendiciones_caja.find_by(id: params[:id])
    render json: { error: 'Rendición no encontrada' }, status: :not_found if @rendicion.nil?
  end

  def paquetes_de(r)
    Rendiciones::Rendir.devoluciones_de(r.delivery, r.club)
  end

  def serialize_paquete(d)
    {
      id: d.id, paciente: d.paciente&.nombre_completo,
      cantidad: d.cantidad.to_f, unidad: d.stock&.unidad || 'g',
      producto: d.stock&.etiqueta, motivo_fallo: d.motivo_fallo,
    }
  end

  def serialize(r)
    {
      id:        r.id,
      estado:    r.estado,
      delivery:  r.delivery&.nombre_completo,
      receptor:  r.receptor&.nombre_completo,
      declarado_ars: r.monto_declarado_ars.to_f,
      recibido_ars:  r.monto_recibido_ars&.to_f,
      diferencia_ars: r.diferencia_ars&.to_f,
      motivo:    r.motivo_ajuste,
      conforme:  r.conforme,
      cobros:    r.cobros_count,
      # Los paquetes que trae sin entregar. Se muestran para que el que recibe sepa qué entra:
      # al recibir se desarman TODOS y su producto vuelve al stock y a la mesa.
      devoluciones: r.pendiente? ? paquetes_de(r).map { |d| serialize_paquete(d) } : [],
      rendida_at: r.rendida_at, recibida_at: r.recibida_at, conformada_at: r.conformada_at,
      # Qué le toca hacer a QUIEN mira: la pantalla no tiene que deducirlo de tres campos.
      puedo_recibir:  r.pendiente? && current_user.id != r.delivery_id,
      puedo_conformar: r.recibida? && r.conforme == false && current_user.id == r.delivery_id,
    }
  end
end
