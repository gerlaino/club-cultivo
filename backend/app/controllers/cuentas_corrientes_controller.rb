# Quién le debe a la organización, y cuánto. La deuda de socios era un KPI de Contabilidad
# —«Por cobrar»— que no llevaba a ningún lado: el número sin la lista de quiénes. Acá está la
# lista completa de pacientes con cuenta corriente, con la deuda de cada uno y cuándo se movió
# por última vez (una deuda de la semana pasada no es lo mismo que una de hace seis meses).
#
# El total sale de la MISMA cuenta que el KPI (`saldo_disponible < 0`): dos números que no
# cierran entre sí es lo primero que hace desconfiar de una pantalla de plata. Sin paginar: es el
# padrón con cuenta corriente, no crece por día, y el buscador y el orden viven en la pantalla.
#
# Sólo administración, como Retiros: es plata de la organización a nombre de personas.
class CuentasCorrientesController < ApplicationController
  before_action :authenticate_user!
  before_action -> { require_feature!(:produccion_dispensa) }
  before_action :require_gestion!

  # GET /cuentas_corrientes — una fila por paciente con cuenta corriente, mayor deudor primero.
  def index
    cuentas = CuentaCorriente.where(club_id: current_user.club_id).includes(:paciente).to_a
    ultimos = CuentaCorrienteMovimiento.where(cuenta_corriente_id: cuentas.map(&:id))
                                       .group(:cuenta_corriente_id).maximum(:created_at)

    filas = cuentas.filter_map { |cc|
      p = cc.paciente
      next if p.nil?

      saldo = cc.saldo_disponible.to_f
      {
        paciente_id:      p.id,
        nombre:           p.nombre_completo,
        dni:              p.dni,
        activo:           p.es_paciente,
        saldo:            saldo,
        deuda:            saldo.negative? ? -saldo : 0.0,
        limite:           cc.limite_credito.to_f,
        porcentaje_limite: cc.porcentaje_consumido,
        ultimo_movimiento: ultimos[cc.id],
      }
    }.sort_by { |f| [-f[:deuda], f[:nombre]] }

    render json: {
      cuentas:      filas,
      total_deuda:  filas.sum { |f| f[:deuda] },
      deudores:     filas.count { |f| f[:deuda].positive? },
    }
  end

  private

  def require_gestion!
    return if %w[admin supervisor super_admin].include?(current_user.role)

    render json: { error: 'No autorizado' }, status: :forbidden
  end
end
