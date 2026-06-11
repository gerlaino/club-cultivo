class IndicacionVencimientoJob < ApplicationJob
  queue_as :default

  UMBRALES_DIAS = [30, 15, 7].freeze

  def perform
    Club.all.find_each { |club| procesar_club(club) }
  end

  private

  def procesar_club(club)
    hoy      = Date.today
    vencidas = []
    por_vencer = {}

    # Indicaciones vencidas y aún activas — alerta diaria
    IndicacionMedica
      .joins(:paciente)
      .where(pacientes: { club_id: club.id, deleted_at: nil })
      .where(activa: true)
      .where('fecha_vencimiento IS NOT NULL AND fecha_vencimiento < ?', hoy)
      .find_each do |ind|
        next if alerta_reciente?(club, ind, 'indicacion_vencida', dias: 1)

        dias_vencida = (hoy - ind.fecha_vencimiento).to_i
        contexto = {
          indicacion_id: ind.id,
          paciente_id:   ind.paciente_id,
          paciente:      ind.paciente.nombre_completo,
          patologia:     ind.patologia,
          vencimiento:   ind.fecha_vencimiento.to_s,
          dias_vencida:  dias_vencida,
        }
        mensaje = "Indicación vencida: #{ind.paciente.nombre_completo} — #{ind.patologia} (venció hace #{dias_vencida} día#{dias_vencida == 1 ? '' : 's'})"

        crear_alertas(club, 'indicacion_vencida', mensaje, 'error', contexto)
        vencidas << ind
      end

    # Indicaciones por vencer en 30, 15 o 7 días
    UMBRALES_DIAS.each do |dias|
      IndicacionMedica
        .joins(:paciente)
        .where(pacientes: { club_id: club.id, deleted_at: nil })
        .where(activa: true)
        .where(fecha_vencimiento: hoy + dias.days)
        .find_each do |ind|
          next if alerta_reciente?(club, ind, 'indicacion_por_vencer', dias: 2)

          contexto = {
            indicacion_id:  ind.id,
            paciente_id:    ind.paciente_id,
            paciente:       ind.paciente.nombre_completo,
            patologia:      ind.patologia,
            vencimiento:    ind.fecha_vencimiento.to_s,
            dias_restantes: dias,
          }
          mensaje = "Indicación por vencer: #{ind.paciente.nombre_completo} — #{ind.patologia} vence en #{dias} día#{dias == 1 ? '' : 's'} (#{ind.fecha_vencimiento.strftime('%d/%m/%Y')})"
          severidad = dias <= 7 ? 'warning' : 'info'

          crear_alertas(club, 'indicacion_por_vencer', mensaje, severidad, contexto)
          por_vencer[dias] ||= []
          por_vencer[dias] << ind
        end
    end

    if vencidas.any? || por_vencer.values.any?(&:any?)
      NotificacionesMailer.resumen_indicaciones(
        club:       club,
        vencidas:   vencidas,
        por_vencer: por_vencer
      ).deliver_later
    end
  end

  def crear_alertas(club, tipo, mensaje, severidad, contexto)
    %w[medico admin].each do |role|
      AlertaInterna.create!(
        club:             club,
        tipo:             tipo,
        mensaje:          mensaje,
        severidad:        severidad,
        destinada_a_role: role,
        contexto:         contexto,
      )
    end
  end

  def alerta_reciente?(club, indicacion, tipo, dias:)
    AlertaInterna
      .where(club: club, tipo: tipo)
      .where("contexto->>'indicacion_id' = ?", indicacion.id.to_s)
      .where('created_at >= ?', dias.days.ago)
      .exists?
  end
end
