class ReprocannVencimientoJob < ApplicationJob
  queue_as :default

  UMBRALES_DIAS = [30, 15, 7].freeze

  def perform
    Club.all.find_each do |club|
      procesar_club(club)
    end
  end

  private

  def procesar_club(club)
    hoy = Date.today

    # Pacientes con REPROCANN vencido (vencimiento < hoy) — alerta diaria si no hay una de hoy
    vencidos = club.pacientes
                   .where.not(reprocann_vencimiento: nil)
                   .where('reprocann_vencimiento < ?', hoy)
                   .where(reprocann_estado: %w[activo pendiente])
                   .to_a

    vencidos.each do |paciente|
      next if alerta_reciente?(club, paciente, 'reprocann_vencido', dias: 1)

      dias_vencido = (hoy - paciente.reprocann_vencimiento).to_i
      AlertaInterna.create!(
        club:             club,
        tipo:             'reprocann_vencido',
        mensaje:          "REPROCANN vencido: #{paciente.nombre_completo} — venció hace #{dias_vencido} día#{dias_vencido == 1 ? '' : 's'}",
        severidad:        'error',
        destinada_a_role: 'admin',
        contexto:         { paciente_id: paciente.id, vencimiento: paciente.reprocann_vencimiento.to_s, dias_vencido: }
      )
    end

    # Pacientes próximos a vencer en 30, 15 o 7 días
    por_vencer = {}
    UMBRALES_DIAS.each do |dias|
      fecha_objetivo = hoy + dias.days

      proximos = club.pacientes
                     .where(reprocann_vencimiento: fecha_objetivo)
                     .where(reprocann_estado: %w[activo pendiente])
                     .to_a

      proximos.each do |paciente|
        next if alerta_reciente?(club, paciente, 'reprocann_por_vencer', dias: 2)

        AlertaInterna.create!(
          club:             club,
          tipo:             'reprocann_por_vencer',
          mensaje:          "REPROCANN por vencer: #{paciente.nombre_completo} vence en #{dias} día#{dias == 1 ? '' : 's'} (#{paciente.reprocann_vencimiento.strftime('%d/%m/%Y')})",
          severidad:        dias <= 7 ? 'warning' : 'info',
          destinada_a_role: 'admin',
          contexto:         { paciente_id: paciente.id, vencimiento: paciente.reprocann_vencimiento.to_s, dias_restantes: dias }
        )
        por_vencer[dias] ||= []
        por_vencer[dias] << paciente

        # Aviso directo al socio en umbrales 15 y 7 días
        if dias <= 15 && paciente.email.present? && club.smtp_configured?
          NotificacionesMailer.aviso_reprocann_paciente(
            paciente:       paciente,
            dias_restantes: dias,
            club:           club
          ).deliver_later
        end
      end
    end

    # Enviar email resumen si hay algo que reportar
    if vencidos.any? || por_vencer.values.any?(&:any?)
      NotificacionesMailer.resumen_reprocann(
        club:        club,
        vencidos:    vencidos,
        por_vencer:  por_vencer
      ).deliver_later
    end
  end

  def alerta_reciente?(club, paciente, tipo, dias:)
    AlertaInterna.where(club: club, tipo: tipo)
                 .where("contexto->>'paciente_id' = ?", paciente.id.to_s)
                 .where('created_at >= ?', dias.days.ago)
                 .exists?
  end
end
