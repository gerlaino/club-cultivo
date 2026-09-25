# Las camas de suelo vivo (ver `Cama`, `docs/PLAN_SUELO_VIVO.md`): alta con su mezcla, edición,
# descanso, «ya está lista», retiro y el riego por cama.
#
# Quién: quien cultiva (admin, supervisor, cultivador), cada uno en las salas que ve. En uso
# personal, la persona. La cama es parte del espacio físico, pero la arma y la trabaja quien
# cultiva: por eso el cultivador también puede darla de alta (en sus salas).
class CamasController < ApplicationController
  before_action :authenticate_user!
  before_action -> { require_feature!(:cultivo) }
  before_action :autorizar!
  before_action :set_cama, except: [:index, :create]

  def index
    camas = scope.includes(:sala).order(:nombre)
    camas = camas.where(sala_id: params[:sala_id]) if params[:sala_id].present?
    camas = camas.vigentes unless params[:incluir_retiradas].present?
    render json: camas.map { |c| CamaSerializer.resumen(c) }
  end

  def show
    render json: CamaSerializer.detalle(@cama, con_costo: con_costo?)
  end

  # POST /camas { cama: {...}, mezcla: { receta_id, base, items } }
  # Con mezcla: queda el registro de armado, se descuenta del depósito y la copia va a la cama.
  # Sin mezcla («ya estaba armada», o armada con cosas que no están en el depósito): sólo la cama.
  def create
    sala = salas_al_alcance.find_by(id: cama_params[:sala_id])
    return render json: { errors: ['Espacio no encontrado'] }, status: :unprocessable_entity unless sala

    cama = current_user.club.camas.new(cama_params.merge(created_by: current_user))
    faltantes = []
    error_mezcla = nil
    ActiveRecord::Base.transaction do
      cama.save!
      mezcla = params[:mezcla]
      if mezcla.present? && (mezcla[:receta_id].present? || mezcla[:items].present?)
        res = Camas::Registrar.call(
          cama: cama, usuario: current_user,
          attrs: { tipo: 'armado', registrado_en: (cama.armada_el || Time.zone.today).in_time_zone.change(hour: 12),
                   observaciones: params.dig(:mezcla, :observaciones) },
          nutricion: mezcla,
        )
        unless res.ok?
          error_mezcla = res.error
          raise ActiveRecord::Rollback
        end
        faltantes = res.faltantes
        cama.update_columns(mezcla: res.registro.nutricion)
      end
    end
    return render json: { errors: ["La mezcla: #{error_mezcla}"] }, status: :unprocessable_entity if error_mezcla

    render json: CamaSerializer.detalle(cama.reload, con_costo: con_costo?).merge(faltantes: faltantes), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  def update
    if cama_params[:sala_id].present? && !salas_al_alcance.exists?(id: cama_params[:sala_id])
      return render json: { errors: ['Espacio no encontrado'] }, status: :unprocessable_entity
    end
    if @cama.update(cama_params)
      render json: CamaSerializer.detalle(@cama.reload, con_costo: con_costo?)
    else
      render json: { errors: @cama.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # Borrar es para una cama cargada por error: si ya tuvo lotes, tiene historia y se RETIRA.
  def destroy
    if @cama.lotes.exists?
      return render json: { error: 'La cama tiene historia (lotes que crecieron en ella): retirala en vez de borrarla' },
                    status: :unprocessable_entity
    end
    @cama.destroy
    head :no_content
  end

  # POST /camas/:id/descansar { dias } | { hasta } | { sin_fecha: true }
  # Empieza el descanso, o lo reprograma si ya descansa. Los días los decide el cultivador cada vez
  # (Germán, 25-sep): la app no sugiere números.
  def descansar
    return render json: { error: 'La cama tiene plantas: descansa cuando se cosecha' }, status: :unprocessable_entity if @cama.estado == 'en_uso'
    return render json: { error: 'La cama está retirada' }, status: :unprocessable_entity if @cama.retirada_el

    hoy   = Time.zone.today
    desde = @cama.descansando? ? @cama.descansa_desde : hoy
    hasta = if params[:sin_fecha].present? then nil
            elsif params[:hasta].present? then (Date.parse(params[:hasta].to_s) rescue :mala)
            elsif params[:dias].present? then desde + params[:dias].to_i.days
            else :falta
            end
    return render json: { error: 'Decí cuántos días, hasta qué fecha, o sin fecha' }, status: :unprocessable_entity if hasta == :falta
    return render json: { error: 'La fecha no es válida' }, status: :unprocessable_entity if hasta == :mala
    if params[:dias].present? && params[:dias].to_i <= 0
      return render json: { error: 'Los días de descanso tienen que ser más que cero' }, status: :unprocessable_entity
    end
    return render json: { error: 'La fecha de fin tiene que ser después de hoy' }, status: :unprocessable_entity if hasta && hasta <= hoy

    @cama.update!(descansa_desde: desde, descansa_hasta: hasta)
    render json: CamaSerializer.detalle(@cama.reload, con_costo: con_costo?)
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  def terminar_descanso
    return render json: { error: 'La cama no está descansando' }, status: :unprocessable_entity unless @cama.estado == 'descansando'
    @cama.terminar_descanso!
    render json: CamaSerializer.detalle(@cama.reload, con_costo: con_costo?)
  end

  def terminar_coccion
    return render json: { error: 'La cama no se está cocinando' }, status: :unprocessable_entity unless @cama.estado == 'cocinando'
    @cama.terminar_coccion!
    render json: CamaSerializer.detalle(@cama.reload, con_costo: con_costo?)
  end

  def retirar
    if @cama.update(retirada_el: Time.zone.today)
      render json: CamaSerializer.detalle(@cama.reload, con_costo: con_costo?)
    else
      render json: { errors: @cama.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # POST /camas/:id/regar { litros, agua, observaciones, registrado_en, nutricion: { receta_id, litros, items } }
  # El riego es por cama (el gesto real: «regar la cama A»). Con plantas, va a cada lote de la cama
  # —así el lote sabe cuándo lo regaron— y el té se descuenta UNA vez y se reparte. Sin plantas (la
  # cama descansa con cobertura), va a la cama.
  def regar
    litros = params[:litros].presence&.to_d
    return render json: { error: 'Decí cuántos litros' }, status: :unprocessable_entity if litros.nil? || litros <= 0
    agua = params[:agua].presence
    if agua && !CamaRegistro::AGUAS.include?(agua)
      return render json: { error: 'Tipo de agua inválido' }, status: :unprocessable_entity
    end
    cuando = params[:registrado_en].present? ? Time.zone.parse(params[:registrado_en].to_s) : Time.current
    return render json: { error: 'La fecha no puede ser futura' }, status: :unprocessable_entity if cuando.to_date > Time.zone.today
    n = params[:nutricion].presence

    lotes = @cama.lotes_en_cultivo.to_a
    if lotes.empty?
      res = Camas::Registrar.call(cama: @cama, usuario: current_user,
                                  attrs: { tipo: 'riego', registrado_en: cuando, litros: litros, agua: agua,
                                           observaciones: params[:observaciones] },
                                  nutricion: n)
      return render json: { error: res.error }, status: :unprocessable_entity unless res.ok?
      return render json: { en: 'cama', registro: CamaSerializer.registro(res.registro, con_costo: con_costo?), faltantes: res.faltantes }, status: :created
    end

    registros = []
    faltantes = []
    ActiveRecord::Base.transaction do
      lotes.each do |lote|
        # El volumen del riego va en el texto, como en el registro del lote («Riego: 20L»): la
        # columna `litros` es la de la receta preparada, y la pone `Nutricion::Aplicar`.
        texto = ["Riego de la #{@cama.nombre}: #{litros.to_s('F').sub(/\.0\z/, '')} L en toda la cama",
                 params[:observaciones].presence].compact.join("\n")
        registros << lote.registros_ambientales.create!(
          user: current_user, club: current_user.club, registrado_en: cuando, agua: agua,
          observaciones: texto,
          fertilizacion: n.present? && (n[:receta_id].present? || n[:items].present?),
          tareas_realizadas: ['riego'],
        )
      end
      if n.present? && (n[:receta_id].present? || n[:items].present?)
        receta = n[:receta_id].present? ? current_user.club.recetas.find(n[:receta_id]) : nil
        if receta && receta.uso != 'riego'
          raise ArgumentError, "La receta «#{receta.nombre}» no es de riego: el té va con una receta de riego"
        end
        items = n[:items].respond_to?(:map) ? n[:items].map { |i| i.to_unsafe_h.symbolize_keys } : nil
        faltantes = Nutricion::Aplicar.new(club: current_user.club, usuario: current_user, registros: registros,
                                           litros: n[:litros].presence || litros, receta: receta, items: items,
                                           sala: @cama.sala).call.faltantes
      end
    end
    render json: { en: 'lotes', lotes_afectados: registros.size, faltantes: faltantes }, status: :created
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  private

  # La plata es de administración (admin, supervisor; en uso personal la persona es admin).
  def con_costo? = current_user.admin? || current_user.supervisor?

  def autorizar!
    return if %w[admin supervisor cultivador].include?(current_user.role)
    render json: { error: 'No autorizado' }, status: :forbidden
  end

  def scope = current_user.club.camas.al_alcance_de(current_user)

  def salas_al_alcance
    salas = current_user.club.salas.cultivo
    if current_user.cultivador?
      salas.where(id: current_user.salas_ids_asignadas)
    elsif current_user.supervisor?
      salas.where(sede_id: current_user.sedes_ids_asignadas)
    else
      salas
    end
  end

  def set_cama
    @cama = scope.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Cama no encontrada' }, status: :not_found
  end

  def cama_params
    params.require(:cama).permit(:nombre, :sala_id, :largo_m, :ancho_m, :profundidad_cm, :armada_el,
                                 :semanas_coccion, :dias_descanso, :frecuencia_top_dress_dias, :notas)
  end
end
