class PesajesManicuraController < ApplicationController
  before_action :authenticate_user!
  before_action :set_lote, except: [:index_admin]
  before_action :set_pesaje, only: [:show, :enviar, :confirmar, :destroy, :reabrir, :reajustar_peso]

  # GET /lotes/:lote_id/pesajes_manicura
  # Manicurador ve sus pesajes activos del lote; admin ve todos.
  def index
    pesajes = if current_user.admin? || current_user.supervisor?
      @lote.pesajes_manicura.includes(:manicurador, :stock, pesadas_plantas: :plant)
    else
      @lote.pesajes_manicura.where(manicurador: current_user)
           .includes(:manicurador, :stock, pesadas_plantas: :plant)
    end
    render json: pesajes.recientes.map { |p| PesajeManicuraSerializer.serialize(p) }
  end

  # GET /pesajes_manicura — admin/supervisor: todos los enviados del club
  def index_admin
    unless current_user.admin? || current_user.supervisor?
      return render json: { error: 'No autorizado' }, status: :forbidden
    end
    pesajes = current_user.club.pesajes_manicura
                          .enviados
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
    # Misma regla que PlantsController#registrar_peso: pesa quien tenga rol de manicura/
    # admin/supervisor Y el lote esté sin asignar o asignado a sí mismo. Así el admin no
    # pisa el pesaje de un manicura ya asignado al lote.
    rol_ok        = current_user.manicura? || current_user.admin? || current_user.supervisor?
    asignacion_ok = @lote.manicurador_id.nil? || @lote.manicurador_id == current_user.id
    unless rol_ok && asignacion_ok
      return render json: { error: 'No estás asignado a este lote' }, status: :forbidden
    end
    unless @lote.estado == 'en_manicura'
      return render json: { error: 'El lote no está en manicura activa' }, status: :unprocessable_entity
    end

    carga_manual = params[:peso_total_g].present?
    enviar_ya    = ActiveModel::Type::Boolean.new.cast(params[:enviar])

    pesaje = @lote.pesajes_manicura.build(
      manicurador: current_user,
      club:        current_user.club,
      fecha_pesaje: Date.today,
      notas:        params[:notas],
    )

    if carga_manual
      pesaje.peso_total_g  = params[:peso_total_g].to_d
      pesaje.plantas_count = params[:plantas_count]
    end

    if pesaje.save
      pesaje.enviar! if enviar_ya && carga_manual
      render json: PesajeManicuraSerializer.serialize(pesaje.reload, include_plantas: true), status: :created
    else
      render json: { errors: pesaje.errors.full_messages }, status: :unprocessable_entity
    end
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
      pesaje = @lote.pesajes_manicura.create!(manicurador: current_user, club: current_user.club, fecha_pesaje: Date.today)

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
      if resto_peso.positive?
        restantes = @lote.plants.where.not(id: individuales_ids)
                                .where('peso_seco IS NULL OR peso_seco <= 0').to_a
        n = restantes.size
        if n.positive?
          base = (resto_peso / n).round(2)
          restantes.each_with_index do |plant, i|
            peso = (i == n - 1) ? (resto_peso - base * (n - 1)) : base # la última absorbe el remanente
            plant.update!(peso_seco: peso)
            pesaje.pesadas_plantas.create!(plant: plant, peso_seco_g: peso, es_promedio: true)
          end
        end
      end

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
