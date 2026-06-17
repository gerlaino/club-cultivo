class PesajesManicuraController < ApplicationController
  before_action :authenticate_user!
  before_action :set_lote, except: [:index_admin]
  before_action :set_pesaje, only: [:show, :enviar, :confirmar, :destroy, :reabrir]

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
  # Manicurador crea un nuevo pesaje del día (borrador).
  def create
    unless current_user.manicura? || current_user.admin? || current_user.supervisor?
      return render json: { error: 'No autorizado' }, status: :forbidden
    end
    unless @lote.estado == 'en_manicura'
      return render json: { error: 'El lote no está en manicura activa' }, status: :unprocessable_entity
    end

    pesaje = @lote.pesajes_manicura.build(
      manicurador: current_user,
      club:        current_user.club,
      fecha_pesaje: Date.today,
      notas:        params[:notas],
    )
    if pesaje.save
      render json: PesajeManicuraSerializer.serialize(pesaje), status: :created
    else
      render json: { errors: pesaje.errors.full_messages }, status: :unprocessable_entity
    end
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
    @pesaje.pesadas_plantas.destroy_all
    @pesaje.destroy
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

  private

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
