class PesajesManicuraController < ApplicationController
  include ManicuraJornadaGuard

  # El pesaje que se mandó sin señal y se reintenta cuando vuelve, cuando resulta que la primera
  # request SÍ había llegado y lo que se perdió fue la respuesta.
  #
  # No es un error de validación aunque viaje como 422: el trabajo está hecho. Se distingue con
  # `ya_registrado: true` para que la cola offline del front lo dé por enviado en vez de marcarlo
  # FALLIDO — que es lo que hacía, avisándole a la manicura de una falla inexistente y mandándola a
  # volver a cargar un pesaje que ya estaba. Ahí sí terminaba en dos jornadas.
  class YaRegistrado < StandardError; end

  before_action :authenticate_user!

  before_action -> { require_feature!(:cultivo) }
  before_action :set_lote, except: [:index_admin]
  before_action :set_pesaje, only: [:show, :enviar, :confirmar, :destroy, :reabrir, :reajustar_peso]

  # GET /lotes/:lote_id/pesajes_manicura
  # Trabajo de equipo: todos los que pueden ver el lote ven TODOS los pesajes (para
  # coordinar qué ya se pesó). Editar/reabrir un pesaje ajeno sigue con su propia guarda.
  def index
    pesajes = @lote.pesajes_manicura.includes(:manicurador, :stock, pesadas_plantas: :plant)
    render json: pesajes.recientes.map { |p| PesajeManicuraSerializer.serialize(p) }
  end

  # GET /pesajes_manicura — admin/supervisor: todos los enviados del club
  def index_admin
    unless current_user.admin? || current_user.supervisor?
      return render json: { error: 'No autorizado' }, status: :forbidden
    end
    # joins(:lote) aplica el default_scope del lote (deleted_at: nil) → un pesaje cuyo lote fue
    # borrado NUNCA aparece en el board (defensa además del cleanup en Lote#soft_delete!).
    pesajes = current_user.club.pesajes_manicura
                          .enviados
                          .joins(:lote)
                          .includes(:lote, :manicurador, :stock, pesadas_plantas: :plant)
                          .order(enviado_at: :desc)
    render json: pesajes.map { |p| PesajeManicuraSerializer.serialize(p, include_plantas: true) }
  end

  # GET /lotes/:lote_id/pesajes_manicura/:id
  def show
    render json: PesajeManicuraSerializer.serialize(@pesaje, include_plantas: true)
  end

  # POST /lotes/:lote_id/pesajes_manicura
  # Crea un pesaje (borrador) para cargar plantas por QR. Si se pasan plantas_count +
  # peso_total_g es una CARGA MANUAL sin QR; con enviar=true se manda a confirmar en el acto.
  def create
    # Cualquier usuario con rol manicura/admin/supervisor del club puede registrar un
    # pesaje en un lote en manicura (es trabajo de equipo sobre el batch — varios pesan a
    # la vez). El "responsable" (manicurador_id) sigue siendo quien lo tiene asignado, pero
    # no bloquea a los demás. La trazabilidad queda cubierta: el pesaje guarda quién lo
    # registró y los de no-admin requieren confirmación antes de impactar el stock.
    unless current_user.manicura? || current_user.admin? || current_user.supervisor?
      return render json: { error: 'No autorizado' }, status: :forbidden
    end
    # Si el lote tiene un manicura asignado, SOLO esa persona registra el pesaje (evita
    # ediciones concurrentes / pesos que se pisan). Si no hay asignado, cualquiera de los
    # roles habilitados puede. (Provisorio hasta afinar el flujo de equipo.)
    if @lote.manicurador_id.present? && @lote.manicurador_id != current_user.id
      return render json: { error: 'Este lote está asignado a otro responsable de manicura. Solo esa persona puede registrar el pesaje.' }, status: :forbidden
    end
    unless @lote.estado == 'en_manicura'
      return render json: { error: 'El lote no está en manicura activa' }, status: :unprocessable_entity
    end

    carga_manual = params[:peso_total_g].present?
    enviar_ya    = ActiveModel::Type::Boolean.new.cast(params[:enviar])
    force_new    = ActiveModel::Type::Boolean.new.cast(params[:force_new])

    # Carga conjunta (pesar el resto de una): si hay una jornada enviada sin confirmar de
    # esta manicura, preguntar antes de abrir una nueva (mismo criterio que el pesaje por QR).
    if carga_manual && (jp = jornada_a_confirmar(@lote, force_new: force_new))
      return render_needs_choice(jp)
    end

    # Continuar el borrador abierto de esta manicura (p.ej. una jornada reabierta) en vez de
    # fragmentar en dos registros; si se pidió una nueva o no hay borrador, se crea una.
    pesaje = @lote.pesajes_manicura.borradores.where(manicurador_id: current_user.id).recientes.first unless force_new
    pesaje ||= @lote.pesajes_manicura.build(
      manicurador: current_user,
      club:        current_user.club,
      fecha_pesaje: Time.zone.today,
      notas:        params[:notas],
    )

    ActiveRecord::Base.transaction do
      pesaje.save!
      if carga_manual
        # La carga conjunta reparte el peso como PROMEDIO entre las plantas seleccionadas
        # (plant_ids) o, si no se seleccionaron, entre las primeras N sin pesar (plantas_count).
        n = distribuir_resto!(pesaje, params[:peso_total_g].to_d,
                              count: params[:plantas_count].to_i, solo_ids: params[:plant_ids])
        if n.zero?
          # La PLANTA es la clave de idempotencia natural de este flujo: se pesa una sola vez, y
          # `distribuir_resto!` sólo toca las que no tienen peso. Si las seleccionadas ya lo tienen,
          # este pesaje ya se aplicó — no hay nada que reintentar ni nada que reportar.
          raise YaRegistrado if plantas_ya_pesadas?(params[:plant_ids])

          raise ArgumentError, 'No hay plantas sin pesar entre las seleccionadas'
        end
        pesaje.enviar! if enviar_ya
      end
    end

    render json: PesajeManicuraSerializer.serialize(pesaje.reload, include_plantas: true), status: :created
  rescue YaRegistrado
    # El `raise` va dentro de la transacción, así que la jornada que se acababa de crear se
    # revierte: no queda una jornada vacía por cada reintento.
    render json: { error: 'Estas plantas ya tienen peso registrado', ya_registrado: true },
           status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  rescue ArgumentError, RuntimeError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # POST /lotes/:lote_id/pesajes_manicura/registrar_directo
  # Atajo del admin/supervisor (última palabra): pesa Y confirma en un solo paso, sin pasar
  # por la cola de aprobación. Acepta pesos individuales por planta y/o una carga conjunta
  # del resto, más un contenedor (stock_id) y sede destino. Solo si el lote no tiene un
  # manicura asignado (o está asignado a sí mismo).
  def registrar_directo
    unless current_user.admin? || current_user.supervisor?
      return render json: { error: 'Solo admin o supervisor pueden registrar directo' }, status: :forbidden
    end
    unless @lote.manicurador_id.nil? || @lote.manicurador_id == current_user.id
      return render json: { error: 'El lote está asignado a un manicura' }, status: :forbidden
    end
    unless @lote.estado == 'en_manicura'
      return render json: { error: 'El lote no está en manicura activa' }, status: :unprocessable_entity
    end

    pesos      = params[:pesos] || []
    resto_peso = params.dig(:resto, :peso_total_g).to_d

    ActiveRecord::Base.transaction do
      stock  = resolver_stock_destino!
      pesaje = @lote.pesajes_manicura.create!(manicurador: current_user, club: current_user.club, fecha_pesaje: Time.zone.today)

      # Pesos individuales (medidos).
      individuales_ids = []
      pesos.each do |pp|
        peso = pp[:peso_seco_g].to_d
        next if peso <= 0
        plant = @lote.plants.find(pp[:plant_id])
        plant.update!(peso_seco: peso)
        pesaje.pesadas_plantas.create!(plant: plant, peso_seco_g: peso, es_promedio: false)
        individuales_ids << plant.id
      end

      # Resto: el peso conjunto se reparte como PROMEDIO entre las plantas que quedan sin
      # pesar (ni individual ahora, ni de un pesaje previo). Cada una queda con es_promedio.
      # `plant_ids` restringe el reparto a las plantas elegidas; sin él, va a todas las que
      # sigan sin pesar (que es el caso de "cargar el resto del lote de una").
      distribuir_resto!(pesaje, resto_peso, excluir_ids: individuales_ids,
                        solo_ids: params.dig(:resto, :plant_ids)) if resto_peso.positive?

      raise ArgumentError, 'Cargá al menos un peso (individual o del resto)' unless pesaje.pesadas_plantas.exists?

      pesaje.confirmar_directo!(confirmado_por: current_user, stock: stock)
      @lote.reload.check_and_finalize_manicura!(finalizador: current_user)
      render json: { stock_id: stock.id, lote_estado: @lote.reload.estado }, status: :created
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Planta o contenedor no encontrado' }, status: :not_found
  rescue ArgumentError, RuntimeError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # DELETE /lotes/:lote_id/pesajes_manicura/:id
  # Borra un pesaje propio que todavía no se confirmó (limpiar jornadas erróneas/duplicadas).
  def destroy
    unless @pesaje.manicurador_id == current_user.id || current_user.admin? || current_user.supervisor?
      return render json: { error: 'No autorizado' }, status: :forbidden
    end
    if @pesaje.confirmado?
      return render json: { error: 'No se puede borrar un pesaje ya confirmado' }, status: :unprocessable_entity
    end

    # Si lo borra un admin/supervisor (no el propio manicurista), avisarle al manicurista
    # que su pesaje se descartó para que lo vuelva a cargar.
    notificar = @pesaje.manicurador_id != current_user.id
    lote_id     = @pesaje.lote_id
    lote_codigo = @pesaje.lote.codigo
    peso_decl   = @pesaje.peso_total_g || @pesaje.peso_calculado_g

    @pesaje.pesadas_plantas.destroy_all
    @pesaje.destroy

    if notificar
      AlertaInterna.create!(
        club:             current_user.club,
        tipo:             'manicura_eliminada',
        mensaje:          "Se eliminó el pesaje del lote #{lote_codigo} (#{peso_decl.to_f.round(1)}g) — volvé a registrarlo",
        severidad:        'warning',
        creada_por:       current_user,
        destinada_a_role: 'manicura',
        contexto:         { lote_id: lote_id, lote_codigo: lote_codigo },
      )
    end

    head :no_content
  end

  # POST /lotes/:lote_id/pesajes_manicura/:id/reabrir
  # Vuelve un pesaje enviado a borrador para corregirlo.
  def reabrir
    unless @pesaje.manicurador_id == current_user.id || current_user.admin? || current_user.supervisor?
      return render json: { error: 'No autorizado' }, status: :forbidden
    end
    unless @pesaje.enviado?
      return render json: { error: 'Solo se puede reabrir un pesaje enviado' }, status: :unprocessable_entity
    end
    @pesaje.update!(estado: 'borrador', enviado_at: nil)

    # Si lo reabre un admin/supervisor (no el propio manicurista), avisarle que su pesaje
    # volvió a borrador para que lo corrija y lo vuelva a enviar. Los datos se conservan.
    if @pesaje.manicurador_id != current_user.id
      AlertaInterna.create!(
        club:             current_user.club,
        tipo:             'manicura_reabierta',
        mensaje:          "El pesaje del lote #{@pesaje.lote.codigo} se reabrió para corrección — revisalo y volvé a enviarlo",
        severidad:        'warning',
        creada_por:       current_user,
        destinada_a_role: 'manicura',
        contexto:         { lote_id: @pesaje.lote_id, lote_codigo: @pesaje.lote.codigo, pesaje_manicura_id: @pesaje.id },
      )
    end

    render json: PesajeManicuraSerializer.serialize(@pesaje)
  end

  # POST /lotes/:lote_id/pesajes_manicura/:id/enviar
  # Manicurador cierra el día y manda a aprobación.
  def enviar
    unless @pesaje.manicurador == current_user || current_user.admin? || current_user.supervisor?
      return render json: { error: 'No autorizado' }, status: :forbidden
    end
    @pesaje.enviar!
    render json: PesajeManicuraSerializer.serialize(@pesaje.reload)
  rescue ArgumentError, RuntimeError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # POST /lotes/:lote_id/pesajes_manicura/:id/confirmar
  # Admin/supervisor confirma el peso y elige el recipiente (stock).
  def confirmar
    unless current_user.admin? || current_user.supervisor?
      return render json: { error: 'Solo admin o supervisor pueden confirmar' }, status: :forbidden
    end

    peso = params.require(:peso_confirmado_g)
    @pesaje.confirmar!(
      confirmado_por:    current_user,
      peso_confirmado_g: peso,
      stock_id:          params[:stock_id],
    )
    render json: PesajeManicuraSerializer.serialize(@pesaje.reload, include_plantas: true)
  rescue ActionController::ParameterMissing => e
    render json: { error: "Falta: #{e.param}" }, status: :unprocessable_entity
  rescue ArgumentError, RuntimeError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Stock no encontrado para este lote' }, status: :not_found
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  # PATCH /lotes/:lote_id/pesajes_manicura/:id/reajustar_peso
  # Corrige el peso de un pesaje confirmado y propaga la diferencia al stock del lote.
  def reajustar_peso
    unless current_user.admin? || current_user.supervisor?
      return render json: { error: 'Solo admin o supervisor pueden reajustar' }, status: :forbidden
    end

    @pesaje.reajustar_peso_confirmado!(
      nuevo_peso: params.require(:peso_confirmado_g),
      usuario:    current_user,
    )
    render json: PesajeManicuraSerializer.serialize(@pesaje.reload, include_plantas: true)
  rescue ActionController::ParameterMissing => e
    render json: { error: "Falta: #{e.param}" }, status: :unprocessable_entity
  rescue ArgumentError, RuntimeError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  private

  # Reparte `peso_total` como PROMEDIO entre las plantas del lote que aún no tienen peso
  # (excluyendo `excluir_ids` y, opcionalmente, limitando a `count` plantas). Crea una
  # pesada por planta con es_promedio: true y le setea el peso_seco. Devuelve cuántas tocó.
  # `solo_ids` (opcional): limita el reparto a esas plantas puntuales (selección explícita
  # del usuario). Si no viene, cae al comportamiento por `count` (primeras N sin pesar).
  # ¿Las plantas que se pidieron pesar YA tienen peso? Se exige que las ids existan en el lote: si
  # alguna no pertenece, no es un pesaje repetido sino un pedido inválido, y ese sí es un error.
  def plantas_ya_pesadas?(ids)
    ids = Array(ids).compact.uniq
    return false if ids.blank?

    plantas = @lote.plants.where(id: ids)
    return false unless plantas.count == ids.size

    plantas.where('peso_seco IS NULL OR peso_seco <= 0').none?
  end

  def distribuir_resto!(pesaje, peso_total, count: nil, solo_ids: nil, excluir_ids: [])
    return 0 if peso_total <= 0
    restantes = pesaje.lote.plants.where.not(id: excluir_ids)
                      .where('peso_seco IS NULL OR peso_seco <= 0')
    restantes = restantes.where(id: solo_ids) if solo_ids.present?
    restantes = restantes.order(:id).to_a
    restantes = restantes.first(count) if count && count.positive? && solo_ids.blank?
    n = restantes.size
    return 0 if n.zero?

    base = (peso_total / n).round(2)
    restantes.each_with_index do |plant, i|
      peso = (i == n - 1) ? (peso_total - base * (n - 1)) : base # la última absorbe el remanente
      plant.update!(peso_seco: peso)
      pesaje.pesadas_plantas.create!(plant: plant, peso_seco_g: peso, es_promedio: true)
    end
    n
  end

  # Contenedor destino para registrar_directo: existente (stock_id) o nuevo. Si viene
  # sede_id y el contenedor no tiene sede, lo asigna a esa sede.
  def resolver_stock_destino!
    stock = if params[:stock_id].present?
      current_user.club.stocks.where(lote_id: @lote.id, forma_producto: 'flor_seca').find(params[:stock_id])
    else
      current_user.club.stocks.create!(
        lote: @lote, genetica: @lote.genetica, origen: 'lote',
        forma_producto: 'flor_seca', estado: 'pendiente_asignacion', cantidad: 0, unidad: 'g',
      )
    end
    if params[:sede_id].present? && stock.sede_id.nil?
      sede = current_user.club.sedes.find(params[:sede_id])
      stock.update!(sede: sede, estado: 'asignado')
    end
    stock
  end

  def set_lote
    @lote = current_user.club.lotes.find(params[:lote_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Lote no encontrado' }, status: :not_found
  end

  def set_pesaje
    @pesaje = @lote.pesajes_manicura.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Pesaje no encontrado' }, status: :not_found
  end
end
