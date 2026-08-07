class PesadasController < ApplicationController
  before_action :authenticate_user!
  before_action -> { require_feature!(:cultivo) }
  before_action :set_lote
  before_action :set_pesada, only: [:destroy]

  # GET /lotes/:lote_id/pesadas
  def index
    authorize Pesada.new(lote: @lote), :index?
    pesadas = @lote.pesadas.includes(:registrado_por).order(registrado_at: :asc)
    render json: pesadas.map { |p| serialize(p) }
  end

  # POST /lotes/:lote_id/pesadas
  def create
    pesada = @lote.pesadas.build(pesada_params)
    pesada.registrado_por = current_user
    pesada.registrado_at  = Time.current

    authorize pesada, :create?

    if pesada.save
      render json: serialize(pesada), status: :created
    else
      render json: { errors: pesada.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /lotes/:lote_id/pesadas/:id
  def destroy
    authorize @pesada, :destroy?
    @pesada.destroy
    head :no_content
  end

  private

  def set_lote
    @lote = current_user.club.lotes.find(params[:lote_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Lote no encontrado' }, status: :not_found
  end

  def set_pesada
    @pesada = @lote.pesadas.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Pesada no encontrada' }, status: :not_found
  end

  def pesada_params
    params.require(:pesada).permit(
      :fase_origen, :fase_destino,
      :peso_humedo_g, :peso_seco_g, :peso_curado_g,
      :manicurado, :notas
    )
  end

  def serialize(p)
    {
      id:             p.id,
      lote_id:        p.lote_id,
      fase_origen:    p.fase_origen,
      fase_destino:   p.fase_destino,
      peso_humedo_g:  p.peso_humedo_g&.to_f,
      peso_seco_g:    p.peso_seco_g&.to_f,
      peso_curado_g:  p.peso_curado_g&.to_f,
      manicurado:     p.manicurado,
      notas:          p.notas,
      registrada_por: p.registrado_por&.first_name,
      registrado_at:  p.registrado_at,
      created_at:     p.created_at,
      aprobada_at:    p.aprobada_at,
      aprobada_por:   p.aprobada_por&.first_name,
    }
  end
end
