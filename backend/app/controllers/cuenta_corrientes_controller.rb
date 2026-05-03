class CuentaCorrientesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!
  before_action :set_paciente

  # GET /pacientes/:paciente_id/cuenta_corriente
  def show
    cc = @paciente.cuenta_corriente || build_default_cc
    render json: serialize(cc)
  end

  # POST /pacientes/:paciente_id/cuenta_corriente/cargar
  def cargar
    cc = find_or_create_cc
    monto = params[:monto].to_d
    descripcion = params[:descripcion].presence || "Carga manual de crédito"

    return render json: { error: "El monto debe ser mayor a 0" }, status: :unprocessable_entity unless monto > 0

    anterior = cc.saldo_disponible
    nuevo    = anterior + monto

    ActiveRecord::Base.transaction do
      cc.update!(saldo_disponible: nuevo, limite_credito: [cc.limite_credito, nuevo].max)
      cc.movimientos.create!(
        tipo: "carga", monto: monto,
        saldo_anterior: anterior, saldo_nuevo: nuevo,
        descripcion: descripcion, created_by: current_user
      )
    end

    render json: serialize(cc.reload), status: :created
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # POST /pacientes/:paciente_id/cuenta_corriente/ajuste
  def ajuste
    cc = find_or_create_cc
    monto       = params[:monto].to_d
    descripcion = params[:descripcion].presence || "Ajuste manual"

    return render json: { error: "El monto no puede ser cero" }, status: :unprocessable_entity if monto.zero?

    anterior = cc.saldo_disponible
    nuevo    = anterior + monto

    if nuevo < 0
      return render json: { error: "El saldo no puede quedar negativo (saldo actual: #{anterior.to_f.round(2)} ARS)" },
                    status: :unprocessable_entity
    end

    ActiveRecord::Base.transaction do
      cc.update!(saldo_disponible: nuevo)
      cc.movimientos.create!(
        tipo: "ajuste", monto: monto,
        saldo_anterior: anterior, saldo_nuevo: nuevo,
        descripcion: descripcion, created_by: current_user
      )
    end

    render json: serialize(cc.reload), status: :created
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # PATCH /pacientes/:paciente_id/cuenta_corriente/set_limite
  def set_limite
    cc    = find_or_create_cc
    nuevo = params[:limite_credito].to_d

    return render json: { error: "El límite debe ser mayor o igual a 0" }, status: :unprocessable_entity if nuevo < 0
    if nuevo < cc.saldo_disponible
      return render json: { error: "El límite (#{nuevo}) no puede ser menor al saldo actual (#{cc.saldo_disponible.to_f.round(2)})" },
                    status: :unprocessable_entity
    end

    cc.update!(limite_credito: nuevo)
    render json: serialize(cc.reload)
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def set_paciente
    @paciente = current_user.club.pacientes.find(params[:paciente_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Paciente no encontrado" }, status: :not_found
  end

  def require_admin!
    render json: { error: "No autorizado" }, status: :forbidden unless current_user.admin?
  end

  def find_or_create_cc
    @paciente.cuenta_corriente ||
      @paciente.create_cuenta_corriente!(club: current_user.club, saldo_disponible: 0, limite_credito: 0)
  end

  def build_default_cc
    CuentaCorriente.new(
      paciente: @paciente, club: current_user.club,
      saldo_disponible: 0, limite_credito: 0
    )
  end

  def serialize(cc)
    movimientos = cc.persisted? ? cc.movimientos.includes(:created_by, :dispensacion).recientes.limit(50) : []
    {
      id:               cc.id,
      paciente_id:      cc.paciente_id,
      limite_credito:   cc.limite_credito.to_f,
      saldo_disponible: cc.saldo_disponible.to_f,
      notas:            cc.notas,
      movimientos:      movimientos.map { |m| serialize_mov(m) },
    }
  end

  def serialize_mov(m)
    {
      id:             m.id,
      tipo:           m.tipo,
      tipo_label:     m.tipo_label,
      monto:          m.monto.to_f,
      saldo_anterior: m.saldo_anterior.to_f,
      saldo_nuevo:    m.saldo_nuevo.to_f,
      descripcion:    m.descripcion,
      dispensacion_id: m.dispensacion_id,
      created_by:     m.created_by&.first_name || m.created_by&.email,
      created_at:     m.created_at,
    }
  end
end
