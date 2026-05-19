class LecturasAmbientalesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_read_access
  before_action :set_sala

  def index
    desde  = params[:desde].present? ? Time.zone.parse(params[:desde]) : 24.hours.ago
    hasta  = params[:hasta].present? ? Time.zone.parse(params[:hasta]) : Time.current
    tipo   = params[:tipo]

    lecturas = LecturaAmbiental
      .de_sala(@sala.id)
      .en_rango(desde, hasta)
      .order(medido_at: :asc)

    lecturas = lecturas.del_tipo(tipo) if tipo.present?

    render json: lecturas.map { |l| serialize(l) }
  end

  def ambiente
    return render json: { error: 'Forbidden' }, status: :forbidden unless read_access?

    desde  = params[:desde].present? ? Time.zone.parse(params[:desde]) : 24.hours.ago
    hasta  = params[:hasta].present? ? Time.zone.parse(params[:hasta]) : Time.current
    tipos  = Array(params[:tipo]).presence
    bucket = params[:bucket].presence || 'raw'

    lecturas = LecturaAmbiental
      .de_sala(@sala.id)
      .en_rango(desde, hasta)
      .order(medido_at: :asc)

    tipos.each { |t| lecturas = lecturas.or(LecturaAmbiental.de_sala(@sala.id).en_rango(desde, hasta).del_tipo(t)) } if tipos
    lecturas = LecturaAmbiental.de_sala(@sala.id).en_rango(desde, hasta).where(tipo: tipos).order(medido_at: :asc) if tipos

    if bucket == 'daily'
      agrupadas = lecturas.group_by { |l| [l.medido_at.to_date, l.tipo] }
      data = agrupadas.map do |(fecha, tipo), grupo|
        {
          fecha:  fecha,
          tipo:   tipo,
          valor:  (grupo.sum(&:valor) / grupo.size.to_f).round(3),
          unidad: grupo.first.unidad,
          n:      grupo.size,
        }
      end.sort_by { |d| [d[:fecha].to_s, d[:tipo]] }
      render json: data
    else
      render json: lecturas.map { |l| serialize(l) }
    end
  end

  def create
    return render json: { error: 'Forbidden' }, status: :forbidden unless write_access?

    lectura = LecturaAmbiental.new(lectura_params.merge(
      sala_id:  @sala.id,
      club_id:  current_user.club_id,
      fuente:   'manual'
    ))

    if lectura.save
      begin
        EvaluarReglasJob.perform_later(@sala.id)
      rescue => e
        Rails.logger.warn "EvaluarReglasJob enqueue failed: #{e.message}"
      end
      render json: serialize(lectura), status: :created
    else
      render json: { errors: lectura.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    return render json: { error: 'Forbidden' }, status: :forbidden unless write_access?

    lectura = LecturaAmbiental.de_sala(@sala.id).find(params[:id])
    lectura.destroy
    head :no_content
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Lectura no encontrada' }, status: :not_found
  end

  private

  def set_sala
    @sala = current_user.club.salas.find(params[:sala_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Sala no encontrada' }, status: :not_found
  end

  def require_read_access
    render json: { error: 'Forbidden' }, status: :forbidden unless read_access?
  end

  def read_access?
    current_user.admin? || current_user.cultivador? || current_user.auditor?
  end

  def write_access?
    current_user.admin? || current_user.cultivador?
  end

  def lectura_params
    params.require(:lectura_ambiental).permit(:tipo, :valor, :unidad, :medido_at, :lote_id)
  end

  def serialize(l)
    {
      id:                  l.id,
      tipo:                l.tipo,
      valor:               l.valor,
      unidad:              l.unidad,
      fuente:              l.fuente,
      medido_at:           l.medido_at,
      sala_id:             l.sala_id,
      lote_id:             l.lote_id,
      origen_record_type:  l.origen_record_type,
      origen_record_id:    l.origen_record_id,
    }
  end
end
