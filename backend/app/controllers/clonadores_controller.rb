# Clonadores de una sala. El alta y el registro ambiental son deliberadamente CHICOS: en un clonador
# no hay riego, ni EC, ni pH —un esqueje sin raíz no absorbe—, así que pedir esos campos sería pedir
# datos que no existen.
class ClonadoresController < ApplicationController
  before_action :authenticate_user!
  before_action :require_cultivo!
  before_action :set_clonador, only: [:update, :destroy, :registrar, :asignar]

  # GET /salas/:sala_id/clonadores  |  GET /clonadores
  def index
    scope = current_user.club.clonadores.includes(:sala, lotes: :plants)
    scope = scope.where(sala_id: params[:sala_id]) if params[:sala_id].present?
    render json: scope.order(:nombre).map { |c| serialize(c) }
  end

  def create
    sala = current_user.club.salas.find_by(id: params.dig(:clonador, :sala_id) || params[:sala_id])
    return render json: { error: 'Sala no encontrada' }, status: :not_found unless sala

    clonador = current_user.club.clonadores.build(clonador_params.merge(sala: sala))
    if clonador.save
      render json: serialize(clonador), status: :created
    else
      render json: { errors: clonador.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @clonador.update(clonador_params)
      render json: serialize(@clonador)
    else
      render json: { errors: @clonador.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # Borrado lógico vía paranoia (`Restorable`): `soft_delete!` es el patrón manual de los modelos
  # legacy (lote/plant/sala), acá no existe.
  def destroy
    @clonador.update!(deleted_by_id: current_user.id)
    @clonador.destroy
    head :no_content
  end

  # POST /clonadores/:id/asignar  { lote_id }
  # Mete UN lote al domo —un clonador aloja uno solo a la vez—. Tiene que estar ENRAIZANDO y en la
  # misma sala: el domo está adentro de un cuarto, no es un destino al que se manda un lote de otro
  # lado. El resto de las reglas las valida el modelo.
  #
  # La capacidad ADVIERTE pero no bloquea: son alvéolos contados a ojo y el que está parado frente
  # al domo sabe mejor que nosotros cuántos esquejes entran. Mismo criterio que la reserva parcial.
  def asignar
    lote = current_user.club.lotes.find_by(id: params[:lote_id])
    return render json: { error: 'Lote no encontrado' }, status: :not_found unless lote

    if lote.estado != 'enraizado'
      return render json: { error: "#{lote.codigo} ya prendió (#{lote.estado}): el clonador es solo para enraizar" },
                    status: :unprocessable_entity
    end

    if lote.update(clonador: @clonador)
      advertencias = []
      if @clonador.capacidad && @clonador.ocupados > @clonador.capacidad
        advertencias << "Quedó con #{@clonador.ocupados} plantas y la capacidad del clonador es " \
                        "#{@clonador.capacidad}: revisá que entren."
      end
      render json: { clonador: serialize(@clonador.reload), advertencias: advertencias }
    else
      render json: { errors: lote.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # POST /clonadores/:id/registrar
  # Registro ambiental del clonador: se crea uno por cada lote que tiene adentro, etiquetado con el
  # clonador. Es el mismo patrón que `salas#registrar_sala`, pero con el microclima que corresponde:
  # adentro del domo hay 90% de humedad mientras la sala marca 60%.
  def registrar
    # Solo los que están ADENTRO (enraizando). Un lote que ya prendió conserva su clonador_id como
    # historia, pero está en el cuarto: grabarle el 90% del domo sería el mismo error que veníamos
    # a arreglar, al revés.
    lotes = @clonador.lotes_adentro
    return render json: { error: 'El clonador no tiene lotes adentro' }, status: :unprocessable_entity if lotes.empty?

    count = 0
    ActiveRecord::Base.transaction do
      lotes.each do |lote|
        r = lote.registros_ambientales.build(registro_params)
        r.user          = current_user
        r.club          = current_user.club
        r.clonador      = @clonador
        r.registrado_en = Time.current
        r.fuente        = 'manual'
        r.save!
        count += 1
      end
    end
    render json: { lotes_afectados: count }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  private

  def set_clonador
    @clonador = current_user.club.clonadores.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Clonador no encontrado' }, status: :not_found
  end

  def require_cultivo!
    return if %w[admin supervisor cultivador].include?(current_user&.role)
    render json: { error: 'No autorizado' }, status: :forbidden
  end

  def clonador_params = params.require(:clonador).permit(:nombre, :capacidad, :activo, :sala_id)

  # Solo lo que existe adentro de un domo: aire, sustrato y el producto usado para enraizar.
  def registro_params
    params.require(:registro_ambiental)
          .permit(:temperatura, :humedad, :temperatura_sustrato, :producto_enraizante, :notas)
  end

  def serialize(c)
    {
      id: c.id, nombre: c.nombre, capacidad: c.capacidad, activo: c.activo,
      sala: { id: c.sala_id, nombre: c.sala&.nombre, kind: c.sala&.kind },
      lotes_count: c.lotes.size, ocupados: c.ocupados, disponibles: c.disponibles,
      ambiente_actual: ambiente_actual(c),
    }
  end

  # Último registro del clonador. Va con su antigüedad, como el de la sala: sin sensores el dato
  # puede ser de hace días y mostrarlo pelado haría creer que es de ahora.
  def ambiente_actual(c)
    r = RegistroAmbiental.where(clonador_id: c.id).order(registrado_en: :desc).first
    return nil unless r
    { temperatura: r.temperatura&.to_f, humedad: r.humedad&.to_f,
      temperatura_sustrato: r.temperatura_sustrato&.to_f,
      producto_enraizante: r.producto_enraizante, registrado_en: r.registrado_en }
  end
end
