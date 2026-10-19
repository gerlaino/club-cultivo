# LOS TRES ESTADOS DE UN PACIENTE (Germán, 18 y 19-oct-2026). Son tres ejes, no uno:
#
# 1. VÍNCULO — de quién es su REPROCANN. Adherente: lo tiene vigente con otra organización (puede
#    retirar). Vinculado: lo tiene, o lo va a tramitar, con esta. Sin dato cuenta como vinculado: los
#    pacientes de una organización son suyos salvo que se diga lo contrario.
#
# 2. REPROCANN. El del ADHERENTE es el que se cargó, tal como figura (no lo tramitamos nosotros). El
#    del VINCULADO lo calcula el sistema y sigue un ciclo:
#      pendiente_entrevista → «Inicié el trámite» → pendiente_aprobacion → (número y vencimiento)
#      → activo → a 30 días de vencer vuelve a pedir entrevista → vencido (y sigue pidiéndola).
#    Dos salidas del ciclo, y de las dos se vuelve con una entrevista nueva:
#      no_indicado — la médica decide no pedirlo · rechazado — el Ministerio rechaza el trámite.
#    Con cualquiera de las dos el paciente queda INACTIVO: no retira (Germán, 19-oct).
#
# 3. PACIENTE. Activo · suspendido (90 días sin retirar, solo y sin bloquear) · inactivo (baja) ·
#    sin aprobar (alta del mostrador que nadie admitió todavía).
#
# La regla vive SÓLO acá: la lista, la ficha, la del médico y los contadores la piden; la pantalla
# muestra lo que esto dice, incluidas las acciones que se pueden dar desde cada paso.
module Pacientes
  module Situacion
    DIAS_AVISO = 30
    CERRADOS   = %w[no_indicado rechazado].freeze

    module_function

    def adherente?(vinculo) = vinculo.to_s == 'otra_organizacion'

    # El estado del REPROCANN, de los datos guardados. Una función pura: los contadores la corren
    # sobre columnas sueltas y la ficha sobre el paciente, y tienen que decir lo mismo.
    def reprocann(estado:, numero:, vencimiento:, vinculo:, hoy: Time.zone.today)
      estado = estado.to_s
      return estado if CERRADOS.include?(estado)
      return 'pendiente_aprobacion' if estado == 'pendiente'
      return 'vencido' if estado == 'vencido' # marcado a mano: lo saben aunque no haya fecha
      return 'vencido' if vencimiento.present? && vencimiento < hoy

      # Tiene REPROCANN si hay número o vencimiento cargado: nadie anota la fecha de algo que no existe.
      tiene = numero.present? || vencimiento.present?
      if adherente?(vinculo)
        # Como se cargó: «activo» vale aunque no tengamos su número (es de otra organización).
        return estado == 'activo' || tiene ? 'activo' : 'sin_dato'
      end

      tiene ? 'activo' : 'pendiente_entrevista'
    end

    # Días que le quedan si vence dentro del aviso; nil si no aplica.
    def vence_en_dias(vencimiento, hoy: Time.zone.today)
      return nil if vencimiento.blank?
      dias = (vencimiento - hoy).to_i
      dias.between?(0, DIAS_AVISO) ? dias : nil
    end

    # ¿Hay que darle entrevista con la médica para pedir (o renovar) su REPROCANN? Sólo vinculados:
    # nuevo sin REPROCANN, a 30 días o menos de vencer, o ya vencido (Germán, 18-oct).
    def pendiente_entrevista?(reprocann, vencimiento:, vinculo:, hoy: Time.zone.today)
      return false if adherente?(vinculo)
      return true if %w[pendiente_entrevista vencido].include?(reprocann)
      reprocann == 'activo' && vence_en_dias(vencimiento, hoy: hoy).present?
    end

    def paciente(es_paciente:, aprobado:, ultima_dispensacion:, hoy: Time.zone.today)
      return 'sin_aprobar' unless aprobado
      return 'inactivo' unless es_paciente
      return 'suspendido' if Paciente.suspendido?(es_paciente: true, ultima_dispensacion: ultima_dispensacion, hoy: hoy)
      'activo'
    end

    # Todo junto, para una fila o una ficha. `agenda` es lo de `Pacientes::Agenda.para` para este
    # paciente; `usuario` decide qué acciones se ofrecen (las mismas que el backend acepta).
    def de(p, ultima_dispensacion:, agenda: nil, usuario: nil, hoy: Time.zone.today)
      agenda ||= {}
      rep = reprocann(estado: p.reprocann_estado, numero: p.reprocann_numero, vencimiento: p.reprocann_vencimiento,
                      vinculo: p.reprocann_vinculo, hoy: hoy)
      entrevista = pendiente_entrevista?(rep, vencimiento: p.reprocann_vencimiento, vinculo: p.reprocann_vinculo, hoy: hoy)
      sit = {
        vinculo:              adherente?(p.reprocann_vinculo) ? 'adherente' : 'vinculado',
        vinculo_sin_dato:     p.reprocann_vinculo.blank?,
        reprocann:            rep,
        vence_en_dias:        rep == 'activo' ? vence_en_dias(p.reprocann_vencimiento, hoy: hoy) : nil,
        pendiente_entrevista: entrevista,
        resultado_el:         CERRADOS.include?(rep) ? p.reprocann_resultado_el : nil,
        tramite_iniciado_el:  rep == 'pendiente_aprobacion' ? p.reprocann_tramite_iniciado_el : nil,
        paciente:             paciente(es_paciente: p.es_paciente, aprobado: p.aprobado_at.present?,
                                       ultima_dispensacion: ultima_dispensacion, hoy: hoy),
        proximo_turno_at:     agenda[:proximo_turno_at],
        falto_turno_el:       agenda[:falto_turno_el],
        turno_sin_cerrar:     agenda[:turno_sin_cerrar] || false,
      }
      sit[:acciones] = usuario ? acciones(sit, usuario) : []
      sit
    end

    # Los pasos que se pueden dar desde acá. El backend valida cada uno (`Paciente#…!`) con la misma
    # regla; esta lista es para que la pantalla no ofrezca lo que se va a rechazar.
    def acciones(sit, usuario)
      salud = usuario.admin? || usuario.super_admin? || usuario.medico?
      admin = usuario.admin? || usuario.super_admin?
      a = []
      return a unless salud

      if sit[:vinculo] == 'adherente'
        a << 'vincular'
        return a
      end

      rep = sit[:reprocann]
      if CERRADOS.include?(rep)
        a << 'volver_a_entrevistar' if admin
        return a
      end
      a << 'dar_turno' if sit[:pendiente_entrevista] && sit[:proximo_turno_at].nil?
      if sit[:pendiente_entrevista]
        a << 'iniciar_tramite'
        a << 'no_indicado'
      end
      if rep == 'pendiente_aprobacion'
        a << 'cargar_aprobado'
        a << 'rechazado'
      end
      a
    end
  end
end
