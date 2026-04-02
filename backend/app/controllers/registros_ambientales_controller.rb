class RegistrosAmbientalesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_lote

  def index
    registros = @lote.registros_ambientales.recientes.limit(30)
    render json: registros.map { |r| serialize(r) }
  end

  def create
    registro = @lote.registros_ambientales.build(registro_params)
    registro.user          = current_user
    registro.club          = current_user.club
    registro.registrado_en = Time.current  # siempre automático

    if params[:archivo_csv].present?
      registro.archivo_csv.attach(params[:archivo_csv])
      registro.nombre_archivo_csv = params[:archivo_csv].original_filename
    end

    if registro.save
      render json: serialize(registro), status: :created
    else
      render json: { errors: registro.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    registro = @lote.registros_ambientales.find(params[:id])
    registro.destroy
    head :no_content
  end

  private

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
      :observaciones, :fuente
    )
  end

  def serialize(r)
    {
      id:                   r.id,
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
      observaciones:        r.observaciones,
      fuente:               r.fuente,
      nombre_archivo_csv:   r.nombre_archivo_csv,
      tiene_csv:            r.archivo_csv.attached?,
      registrado_en:        r.registrado_en,
      usuario:              r.user.nombre_completo,
      created_at:           r.created_at
    }
  end
end

