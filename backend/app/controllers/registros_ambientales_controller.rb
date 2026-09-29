class RegistrosAmbientalesController < ApplicationController
  before_action :authenticate_user!
  before_action -> { require_feature!(:cultivo) }
  before_action :set_lote

  def index
    registros = @lote.registros_ambientales.recientes.limit(30)
    render json: registros.map { |r| serialize(r) }
  end

  def create
    registro = @lote.registros_ambientales.build(registro_params)
    registro.user          = current_user
    registro.club          = current_user.club
    registro.registrado_en = params.dig(:registro_ambiental, :registrado_en).present? ?
      Time.zone.parse(params.dig(:registro_ambiental, :registrado_en)) : Time.current

    if params[:archivo_csv].present?
      registro.archivo_csv.attach(params[:archivo_csv])
      registro.nombre_archivo_csv = params[:archivo_csv].original_filename
    end

    if registro.save
      # «Aplicar receta»: descuenta del depósito, cuesta al lote, deja la copia en el registro.
      faltantes = aplicar_nutricion!([registro], sala: nil)
      render json: serialize(registro.reload).merge(faltantes: faltantes), status: :created
    else
      render json: { errors: registro.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    unless current_user.admin?
      return render json: { error: 'Solo un administrador puede borrar registros' }, status: :forbidden
    end
    registro = @lote.registros_ambientales.find(params[:id])
    registro.destroy
    head :no_content
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Registro no encontrado' }, status: :not_found
  end

  private

  # `nutricion: { receta_id, litros, items: [{ insumo_id, cantidad, modo_faltante }] }`.
  # Sin receta ni items no hay nada que aplicar: «se fertilizó pero no se especificó cómo».
  def aplicar_nutricion!(registros, sala:)
    n = params[:nutricion].presence || params.dig(:registro_ambiental, :nutricion)
    return [] if n.blank? || (n[:receta_id].blank? && n[:items].blank?)
    receta = n[:receta_id].present? ? current_user.club.recetas.find(n[:receta_id]) : nil
    items  = n[:items].respond_to?(:map) ? n[:items].map { |i| i.to_unsafe_h.symbolize_keys } : nil
    res = Nutricion::Aplicar.new(club: current_user.club, usuario: current_user, registros: registros,
                                 litros: n[:litros], receta: receta, items: items, sala: sala).call
    res.faltantes
  end

  def set_lote
    @lote = current_user.club.lotes.find(params[:lote_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Lote no encontrado' }, status: :not_found
  end

  def registro_params
    params.require(:registro_ambiental).permit(
      :temperatura, :humedad, :co2, :ph, :ec,
      :temperatura_sustrato, :ph_runoff, :ec_runoff, :ppfd,
      :horas_luz, :espectro_luz, :fase_nutricional,
      :ml_nutrientes_litro, :notas_nutricion,
      :fertilizacion, :notas_fertilizacion,
      :estado_general, :plagas_observadas,
      # Qué se aplicó contra la plaga, aparte de qué se vio. Va separado de las notas de
      # fertilización a propósito: en un producto medicinal, un fungicida y el bloom no pueden
      # terminar en el mismo campo de texto.
      :fitosanitario, :fitosanitario_motivo, :carencia_dias,
      :observaciones, :fuente, :agua, :registrado_en,
      tareas_realizadas: []
    )
  end

  def serialize(r)
    {
      id:                   r.id,
      nutricion:            r.nutricion,
      receta_id:            r.receta_id,
      litros:               r.litros,
      temperatura:          r.temperatura,
      humedad:              r.humedad,
      vpd:                  r.vpd,
      co2:                  r.co2,
      ph:                   r.ph,
      ec:                   r.ec,
      temperatura_sustrato: r.temperatura_sustrato,
      ph_runoff:            r.ph_runoff,
      ppfd:                 r.ppfd,
      horas_luz:            r.horas_luz,
      espectro_luz:         r.espectro_luz,
      fertilizacion:        r.fertilizacion,
      notas_fertilizacion:  r.notas_fertilizacion,
      estado_general:       r.estado_general,
      plagas_observadas:    r.plagas_observadas,
      fitosanitario:        r.fitosanitario,
      fitosanitario_motivo: r.fitosanitario_motivo,
      carencia_dias:        r.carencia_dias,
      observaciones:        r.observaciones,
      agua:                 r.agua,
      fuente:               r.fuente,
      punto_medicion:       r.punto_medicion,
      tareas_realizadas:    r.tareas_realizadas || [],
      nombre_archivo_csv:   r.nombre_archivo_csv,
      tiene_csv:            r.archivo_csv.attached?,
      registrado_en:        r.registrado_en,
      usuario:              r.user.nombre_completo,
      created_at:           r.created_at
    }
  end
end

