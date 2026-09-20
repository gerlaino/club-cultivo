# Los avisos que llegan al TELÉFONO (push), y quién puede elegir cada uno.
#
# Es la única lista. La pantalla de «Mi perfil → Notificaciones» pide `para(user)` y muestra
# eso; `PushNotificationService` pregunta `User#quiere_push?(tipo)` antes de encolar. Si un tipo
# no está acá, no se ofrece y no se manda: no hay avisos «de fábrica» que nadie pueda apagar.
#
# Dos familias, y nada más (Germán, 20-sep-2026):
#   · «Te piden algo»: alguien hizo algo y espera tu visto. Prendidas de entrada.
#   · «Recordatorios»: lo que el sistema deduce solo. Apagadas de entrada en una organización
#     —es lo que cansa si no lo pediste—; en uso personal, prendidos los del ciclo y la
#     cosecha: no hay nadie más que le avise, y es lo que lo hace sentir profesional.
#
# Cada persona ve SÓLO los avisos que su rol puede recibir y SÓLO de los módulos que su
# organización tiene. Campos: `roles` = quién lo recibe en una organización · `feature` =
# módulo que tiene que estar contratado (nil = siempre) · `personal` = si al cultivador de casa
# (que es admin) se le ofrece; por defecto, sí cuando `roles` incluye admin · `default` =
# prendido de entrada · `default_personal` = ídem en uso personal (si no está, vale `default`).
module Notificaciones
  module Catalogo
    EQUIPO = %w[admin cultivador supervisor manicura dispensador delivery].freeze

    TE_PIDEN = 'Te piden algo'
    RECORD   = 'Recordatorios'

    GRUPOS = {
      TE_PIDEN => 'Alguien hizo algo y espera tu visto. Vienen prendidos.',
      RECORD   => 'Lo que la app deduce sola de tus datos. Prendé los que te sirvan.',
    }.freeze

    TIPOS = [
      # ── Te piden algo ────────────────────────────────────────────────────────────────
      { clave: 'pesaje_para_confirmar', grupo: TE_PIDEN, label: 'Pesaje para confirmar',
        desc: 'La manicura envió un pesaje y espera tu confirmación.',
        roles: %w[admin], feature: 'cultivo', personal: false, default: true },
      { clave: 'reposicion_mostrador', grupo: TE_PIDEN, label: 'Reponer en el mostrador',
        desc: 'Quien atiende pidió reponer un producto.',
        roles: %w[admin supervisor], feature: 'produccion_dispensa', default: true },
      { clave: 'caja_sin_cerrar',  grupo: TE_PIDEN, label: 'Caja sin cerrar',
        desc: 'Pasó la hora límite y hay una caja del mostrador abierta.',
        roles: %w[admin], feature: 'produccion_dispensa', default: true },
      { clave: 'tarea_asignada',   grupo: TE_PIDEN, label: 'Tarea nueva asignada a vos',
        desc: 'Cuando alguien te asigna una tarea.',
        roles: EQUIPO, feature: nil, personal: false, default: true },
      { clave: 'plan_vence',       grupo: TE_PIDEN, label: 'Plan por vencer',
        desc: 'Una semana antes y el día que vence.',
        roles: %w[admin], feature: nil, default: true },

      # ── Recordatorios ────────────────────────────────────────────────────────────────
      { clave: 'recordatorio_tarea', grupo: RECORD, label: 'Recordatorios de tareas',
        desc: 'Los que marcás con «Recordarme» al crear una tarea: te llegan ese día o el día antes, a las 8.',
        roles: EQUIPO, feature: nil, personal: true, default: true },
      { clave: 'hitos_cultivo',    grupo: RECORD, label: 'Próximos pasos del ciclo',
        desc: 'Cuándo un lote llega a sus días de vegetativo (¿pasa a floración?), a la cosecha estimada (mirar tricomas), al fin del secado y del curado. Te avisa unos días antes.',
        roles: %w[admin], feature: 'cultivo', default: false, default_personal: true },
      { clave: 'cosecha_pendiente', grupo: RECORD, label: 'Cosecha pendiente',
        desc: 'Un lote pasó su fecha estimada de cosecha y sigue en floración.',
        roles: %w[admin], feature: 'cultivo', default: false, default_personal: true },
      { clave: 'tarea_vencida',    grupo: RECORD, label: 'Tarea vencida',
        desc: 'Una tarea del cultivo quedó sin hacer.',
        roles: %w[admin], feature: 'cultivo', default: false },
      { clave: 'lote_critico',     grupo: RECORD, label: 'Lote en estado crítico',
        desc: 'Un lote con plantas enfermas o con problemas serios.',
        roles: %w[admin], feature: 'cultivo', default: false },
      { clave: 'ambiente',         grupo: RECORD, label: 'Ambiente fuera de rango',
        desc: 'Temperatura, humedad, pH o EC fuera de lo que configuraste, o un espacio sin registro.',
        roles: %w[admin], feature: 'cultivo', default: false },
      { clave: 'reponer_insumos',  grupo: RECORD, label: 'Reponer nutrientes o insumos',
        desc: 'Cuando un producto del depósito llega a su mínimo.',
        roles: %w[admin supervisor], feature: 'cultivo', default: false, default_personal: true },
      { clave: 'saldo_cc_bajo',    grupo: RECORD, label: 'Saldo bajo de un paciente',
        desc: 'La cuenta corriente (o el crédito en gramos) de un paciente quedó por debajo del umbral.',
        roles: %w[admin], feature: 'produccion_dispensa', default: false },
    ].freeze

    CLAVES = TIPOS.map { |t| t[:clave] }.freeze

    def self.tipo(clave) = TIPOS.find { |t| t[:clave] == clave.to_s }

    # Los que ESTA persona puede elegir: por su rol (o por ser el cultivador de casa) y por
    # los módulos de su organización.
    def self.para(user)
      club = user.club
      return [] if club.nil?
      TIPOS.select do |t|
        ofrecido = club.personal? ? t.fetch(:personal, t[:roles].include?('admin')) : t[:roles].include?(user.role)
        ofrecido && (t[:feature].nil? || club.feature?(t[:feature]))
      end
    end

    def self.default_de(tipo, club)
      d = club.personal? ? tipo.fetch(:default_personal, tipo[:default]) : tipo[:default]
      d == true
    end
  end
end
