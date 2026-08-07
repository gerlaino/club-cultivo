class CuentaCorrientesController < ApplicationController
  before_action :authenticate_user!
  before_action -> { require_feature!(:produccion_dispensa) }
  # Mostrar saldo y registrar pagos: roles de mostrador (incluye dispensador).
  # Configurar crédito/límites/ajustes: solo admin/supervisor.
  before_action :require_cobro_access!, only: [:show, :registrar_pago]
  before_action :require_admin!,        except: [:show, :registrar_pago]
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

  # PATCH /pacientes/:paciente_id/cuenta_corriente/toggle_gramos
  def toggle_gramos
    cc = find_or_create_cc
    cc.update!(credito_gramos_activo: !cc.credito_gramos_activo)
    render json: serialize(cc.reload)
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # PATCH /pacientes/:paciente_id/cuenta_corriente/set_limite_g
  def set_limite_g
    cc    = find_or_create_cc
    nuevo = params[:limite_credito_g].to_d
    return render json: { error: "El límite debe ser mayor a 0" }, status: :unprocessable_entity if nuevo <= 0
    cc.update!(limite_credito_g: nuevo)
    render json: serialize(cc.reload)
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # POST /pacientes/:paciente_id/cuenta_corriente/cargar_g
  def cargar_g
    cc     = find_or_create_cc
    gramos = params[:gramos].to_d
    descripcion = params[:descripcion].presence || "Carga de crédito en gramos"

    return render json: { error: "Los gramos deben ser mayor a 0" }, status: :unprocessable_entity unless gramos > 0
    return render json: { error: "Activá el crédito en gramos primero" }, status: :unprocessable_entity unless cc.credito_gramos_activo?

    nuevo = cc.saldo_disponible_g.to_d + gramos
    if cc.limite_credito_g.present? && nuevo > cc.limite_credito_g.to_d
      return render json: { error: "La carga excede el límite de crédito en gramos (#{cc.limite_credito_g.to_f}g)" }, status: :unprocessable_entity
    end

    cc.update!(saldo_disponible_g: nuevo)
    render json: serialize(cc.reload), status: :created
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # POST /pacientes/:paciente_id/cuenta_corriente/registrar_pago
  # Registra un pago real del socio: crea el asiento de ingreso (aporte_socio)
  # —que aparece en el libro contable y acredita la cuenta corriente, saldando
  # la deuda y dejando saldo a favor si paga de más—. Disponible para mostrador.
  def registrar_pago
    cc    = find_or_create_cc
    monto = params[:monto].to_d
    return render json: { error: "El monto debe ser mayor a 0" }, status: :unprocessable_entity unless monto > 0

    sede_id = params[:sede_id].presence ||
              current_user.sedes_ids_asignadas.first ||
              current_user.club.sedes.activas.first&.id
    return render json: { error: "No hay una sede para asignar el pago" }, status: :unprocessable_entity unless sede_id

    medio = params[:medio_pago].presence || 'efectivo'
    unless MovimientoContable::MEDIOS_PAGO.include?(medio)
      return render json: { error: "Medio de pago inválido" }, status: :unprocessable_entity
    end

    # El after_create del movimiento acredita la cuenta corriente del paciente
    MovimientoContable.create!(
      club:        current_user.club,
      sede_id:     sede_id,
      paciente:    @paciente,
      created_by:  current_user,
      tipo:        'ingreso',
      categoria:   'aporte_socio',
      descripcion: "Pago de #{@paciente.nombre_completo}",
      monto_ars:   monto,
      fecha:       Date.current,
      pagado:      true,
      medio_pago:  medio,
    )

    render json: serialize(cc.reload), status: :created
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
    render json: { error: "No autorizado" }, status: :forbidden unless current_user.admin? || current_user.supervisor?
  end

  # Mostrador: admin, supervisor y dispensador pueden ver saldo y registrar pagos
  def require_cobro_access!
    return if current_user.admin? || current_user.supervisor? || current_user.dispensador?
    render json: { error: "No autorizado" }, status: :forbidden
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
      id:                    cc.id,
      paciente_id:           cc.paciente_id,
      limite_credito:        cc.limite_credito.to_f,
      saldo_disponible:      cc.saldo_disponible.to_f,
      credito_gramos_activo: cc.credito_gramos_activo,
      limite_credito_g:      cc.limite_credito_g&.to_f,
      saldo_disponible_g:    cc.saldo_disponible_g&.to_f || 0.0,
      notas:                 cc.notas,
      movimientos:           movimientos.map { |m| serialize_mov(m) },
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
