# Lo que cada persona sacó del cajón y todavía no cerró.
#
# El saldo NO se guarda: se calcula sumando los retiros abiertos de cada uno. Un saldo almacenado
# y sus movimientos son dos datos que hay que mantener coincidiendo, y cuando se despegan gana el
# que mira primero. Acá hay una sola fuente de verdad.
#
# Sólo administración: es plata de la organización a nombre de personas.
class RetirosCajaController < ApplicationController
  before_action :authenticate_user!
  before_action -> { require_feature!(:produccion_dispensa) }
  before_action :require_gestion!

  # GET /retiros_caja — agrupado por persona, los abiertos primero
  def index
    abiertos = MovimientoContable.where(club_id: current_user.club_id)
                                 .retiros_abiertos
                                 .includes(:retirado_por, :sede)
                                 .order(fecha: :desc, created_at: :desc)

    por_persona = abiertos.group_by(&:retirado_por_id).map do |user_id, movs|
      quien = movs.first.retirado_por
      {
        user_id: user_id,
        nombre:  quien&.nombre_completo || 'Sin asignar',
        rol:     quien&.role,
        debe:    movs.sum { |m| m.monto_ars.to_f },
        retiros: movs.map { |m| serialize(m) },
      }
    end.sort_by { |p| -p[:debe] }

    render json: {
      por_persona: por_persona,
      total_abierto: por_persona.sum { |p| p[:debe] },
      # Los últimos cerrados, para ver qué se hizo con cada uno sin ir al libro entero.
      saldados: MovimientoContable.where(club_id: current_user.club_id)
                                  .retiros.where.not(saldado_at: nil)
                                  .includes(:retirado_por, :saldado_por, :saldado_con)
                                  .order(saldado_at: :desc).limit(20).map { |m| serialize(m) },
    }
  end

  # POST /retiros_caja/:id/saldar { forma: devuelto|comprobante|sueldo, categoria?, notas? }
  def saldar
    retiro = MovimientoContable.where(club_id: current_user.club_id).retiros.find(params[:id])

    res = Caja::SaldarRetiro.call(
      retiro: retiro, usuario: current_user, forma: params[:forma],
      categoria: params[:categoria], notas: params[:notas]
    )

    if res.ok?
      render json: serialize(res.retiro.reload)
    else
      render json: { error: res.error }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Retiro no encontrado' }, status: :not_found
  end

  private

  def require_gestion!
    return if %w[admin supervisor super_admin].include?(current_user.role)

    render json: { error: 'No autorizado' }, status: :forbidden
  end

  def serialize(m)
    {
      id:            m.id,
      fecha:         m.fecha,
      monto_ars:     m.monto_ars.to_f,
      descripcion:   m.descripcion,
      sede:          m.sede&.nombre,
      retirado_por:  m.retirado_por&.nombre_completo,
      saldado:       m.saldado_at.present?,
      saldado_at:    m.saldado_at,
      saldado_como:  m.saldado_como,
      saldado_por:   m.saldado_por&.nombre_completo,
      # Qué generó el cierre: el egreso con su categoría, o la devolución.
      resultado:     m.saldado_con && { tipo: m.saldado_con.tipo, categoria: m.saldado_con.categoria,
                                        categoria_label: m.saldado_con.categoria_label },
    }
  end
end
