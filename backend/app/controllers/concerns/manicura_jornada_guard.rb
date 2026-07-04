# Evita crear una jornada de pesaje nueva "en silencio" cuando la manicura ya tiene una
# jornada ENVIADA (sin confirmar) para el mismo lote. En vez de duplicar, el backend avisa
# (409 needs_choice) para que el front pregunte "¿seguir la anterior o empezar una nueva?".
#
# La elección se resuelve del lado del front:
#   - "Seguir la anterior" → POST .../reabrir (vuelve a borrador) y reintenta el registro.
#   - "Empezar una nueva"  → reintenta con force_new=1 (saltea este guard).
module ManicuraJornadaGuard
  extend ActiveSupport::Concern

  private

  # Jornada enviada sin confirmar del usuario actual para este lote (la candidata a continuar).
  # nil si no hay ninguna.
  def jornada_enviada_pendiente(lote)
    lote.pesajes_manicura.enviados.where(manicurador_id: current_user.id).recientes.first
  end

  # ¿Hay que preguntarle a la manicura antes de abrir una jornada nueva?
  # Solo cuando no fuerza una nueva, no tiene un borrador abierto, y sí existe una enviada.
  def jornada_a_confirmar(lote, force_new:)
    return nil if force_new
    return nil if lote.pesajes_manicura.borradores.where(manicurador_id: current_user.id).exists?
    jornada_enviada_pendiente(lote)
  end

  def render_needs_choice(jornada)
    render json: {
      needs_choice: true,
      jornada_enviada: {
        id:      jornada.id,
        plantas: jornada.plantas_registradas_count,
        gramos:  jornada.peso_calculado_g.to_f.round(1),
      },
    }, status: :conflict
  end
end
