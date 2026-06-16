# Asignación automática post-cosecha.
#
# Corre a diario. Para cada club revisa los lotes en estado 'cosecha' (esperando
# manicura) que ya llevan >= `postcosecha_dias` días sin avanzar, y actúa según la
# config del club guardada en `clubs.alertas_config` (jsonb):
#
#   postcosecha_dias                => entero. Días de gracia antes de actuar.
#                                      0 o ausente => feature desactivada para el club.
#   postcosecha_modo                => 'avisar' (default) | 'asignar_automatico'
#   postcosecha_manicura_default_id => User#id (manicura) a usar cuando hay varios.
#
# Cascada de asignación (modo asignar_automatico):
#   - 1 sólo manicura            => se le asigna a ese.
#   - varios manicuras           => al default configurado; si no hay default, se
#                                   deja pendiente y se avisa al admin para que elija.
#   - sin manicuras              => supervisor; si no hay, admin.
#
# Idempotencia:
#   - asignar_automatico mueve el lote a 'en_manicura' (deja de ser 'cosecha'), así
#     que un lote nunca se asigna dos veces.
#   - avisar / pendiente de elección sólo crean una alerta por lote por día.
class AsignacionPostcosechaJob < ApplicationJob
  queue_as :default

  def perform
    Club.activos.find_each { |club| procesar_club(club) }
  end

  private

  def procesar_club(club)
    cfg  = club.alertas_config || {}
    dias = cfg['postcosecha_dias'].to_i
    return if dias <= 0

    modo  = cfg['postcosecha_modo'].presence || 'avisar'
    corte = dias.days.ago

    club.lotes.where(estado: 'cosecha').find_each do |lote|
      cosechado_en = fecha_cosecha(lote)
      next if cosechado_en.nil? || cosechado_en > corte

      if modo == 'asignar_automatico'
        asignar(club, lote, cfg)
      else
        avisar(club, lote, cosechado_en)
      end
    end
  rescue StandardError => e
    Rails.logger.warn "AsignacionPostcosechaJob: club #{club.id} falló: #{e.message}"
  end

  # Momento en que el lote entró a 'cosecha' (último evento de cambio de estado).
  def fecha_cosecha(lote)
    lote.lote_eventos.where(estado_nuevo: 'cosecha').maximum(:registrado_en)
  end

  # ── modo avisar ───────────────────────────────────────────────
  def avisar(club, lote, cosechado_en)
    return if alerta_de_hoy?(club, lote)

    dias_real = ((Time.current - cosechado_en) / 1.day).floor
    AlertaInterna.create!(
      club:             club,
      tipo:             'cosecha_pendiente',
      mensaje:          "Lote #{lote.codigo} lleva #{dias_real} día#{dias_real == 1 ? '' : 's'} cosechado sin pasar a manicura.",
      severidad:        'warning',
      destinada_a_role: 'admin',
      lote:             lote,
      contexto:         { lote_id: lote.id, lote_codigo: lote.codigo, dias: dias_real, accion: 'postcosecha_avisar' }
    )
  end

  # ── modo asignar_automatico ───────────────────────────────────
  def asignar(club, lote, cfg)
    actor = admin_del_club(club)
    return unless actor # sin un usuario actor no podemos registrar eventos/alertas

    target = manicurador_objetivo(club, cfg)
    if target.nil?
      pedir_eleccion(club, lote, actor) # varios manicuras y sin default
      return
    end

    lote.asignar_manicurador!(manicurador: target, asignado_por: actor)
    crear_tarea_manicura(club, lote, target, actor)
  rescue StandardError => e
    Rails.logger.warn "AsignacionPostcosechaJob: lote #{lote.id} no se pudo asignar: #{e.message}"
  end

  def manicurador_objetivo(club, cfg)
    manicuras = club.users.where(role: 'manicura').to_a
    case manicuras.size
    when 1 then manicuras.first
    when 0 then club.users.where(role: 'supervisor').first || club.users.where(role: 'admin').first
    else
      default_id = cfg['postcosecha_manicura_default_id']
      default_id.present? ? manicuras.find { |u| u.id == default_id.to_i } : nil
    end
  end

  def pedir_eleccion(club, lote, _actor)
    return if alerta_de_hoy?(club, lote)

    AlertaInterna.create!(
      club:             club,
      tipo:             'cosecha_pendiente',
      mensaje:          "Lote #{lote.codigo} listo para manicura: hay varios manicuras y no definiste uno por defecto. Asignalo manualmente.",
      severidad:        'warning',
      destinada_a_role: 'admin',
      lote:             lote,
      contexto:         { lote_id: lote.id, lote_codigo: lote.codigo, accion: 'postcosecha_elegir_manicura' }
    )
  end

  def crear_tarea_manicura(club, lote, target, actor)
    return if Tarea.where(lote_id: lote.id, tipo: 'cosecha', estado: %w[pendiente en_progreso])
                   .where("titulo LIKE ?", 'Manicura%').exists?

    Tarea.create!(
      club:             club,
      creada_por:       actor,
      asignada_a:       target,
      lote:             lote,
      sala:             lote.sala,
      titulo:           "Manicura — Lote #{lote.codigo}",
      descripcion:      "Asignación automática post-cosecha. Procesar la manicura del lote #{lote.codigo}.",
      tipo:             'cosecha',
      estado:           'pendiente',
      prioridad:        'alta',
      fecha_programada: Date.current
    )
  end

  # ── helpers ───────────────────────────────────────────────────
  def admin_del_club(club)
    club.users.where(role: 'admin').first
  end

  def alerta_de_hoy?(club, lote)
    AlertaInterna.where(club_id: club.id, lote_id: lote.id, tipo: 'cosecha_pendiente')
                 .where("created_at >= ?", Date.current.beginning_of_day)
                 .exists?
  end
end
