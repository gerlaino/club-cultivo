# Los avisos que llegan al TELÉFONO (push), y quién puede elegir cada uno.
#
# Es la única lista. La pantalla de «Mi perfil → Notificaciones» pide `para(user)` y muestra
# eso; `PushNotificationService` pregunta `User#quiere_push?(tipo)` antes de encolar. Si un tipo
# no está acá, no se ofrece y no se manda: no hay avisos «de fábrica» que nadie pueda apagar.
#
# Regla que ordena la lista (Germán, 20-sep-2026): cada persona ve SÓLO los avisos que su rol
# puede recibir y SÓLO de los módulos que su organización tiene. Una manicura ve una fila; un
# admin de una organización con dispensa ve diez; el cultivador de casa ve las de cultivo.
#
# Campos: `roles` = quién lo recibe en una organización · `feature` = módulo que tiene que
# estar contratado (nil = siempre) · `personal` = si al cultivador de casa (que es admin) se le
# ofrece; por defecto, sí cuando `roles` incluye admin · `default` = prendido de entrada, o el
# nombre de un módulo que lo decide (ambiente: sólo con IoT tiene sentido de entrada).
module Notificaciones
  module Catalogo
    EQUIPO = %w[admin cultivador supervisor manicura dispensador delivery].freeze

    TIPOS = [
      { clave: 'hitos_cultivo',    grupo: 'Cultivo', label: 'Lo que viene en tu cultivo',
        desc: 'Días de vegetativo cumplidos, cosecha estimada, fin de secado y de curado.',
        roles: %w[admin], feature: 'cultivo', default: true },
      { clave: 'ambiente',         grupo: 'Cultivo', label: 'Ambiente',
        desc: 'Sin registro ambiental, o temperatura, humedad, pH o EC fuera de rango.',
        roles: %w[admin], feature: 'cultivo', default: 'iot' },
      { clave: 'cosecha_pendiente', grupo: 'Cultivo', label: 'Cosecha pendiente',
        desc: 'Un lote pasó su fecha estimada de cosecha.',
        roles: %w[admin], feature: 'cultivo', default: true },
      { clave: 'tarea_vencida',    grupo: 'Cultivo', label: 'Tarea vencida',
        desc: 'Una tarea del cultivo quedó sin hacer.',
        roles: %w[admin], feature: 'cultivo', default: true },
      { clave: 'lote_critico',     grupo: 'Cultivo', label: 'Lote en estado crítico',
        desc: 'Un lote con plantas enfermas o con problemas serios.',
        roles: %w[admin], feature: 'cultivo', default: true },
      { clave: 'pesaje_para_confirmar', grupo: 'Post-cosecha', label: 'Pesaje para confirmar',
        desc: 'La manicura envió un pesaje y espera tu confirmación.',
        roles: %w[admin], feature: 'cultivo', personal: false, default: true },
      { clave: 'caja_sin_cerrar',  grupo: 'Mostrador', label: 'Caja sin cerrar',
        desc: 'Pasó la hora límite y hay una caja del mostrador abierta.',
        roles: %w[admin], feature: 'produccion_dispensa', default: true },
      { clave: 'reposicion_mostrador', grupo: 'Mostrador', label: 'Reponer en el mostrador',
        desc: 'Quien atiende pidió reponer un producto.',
        roles: %w[admin supervisor], feature: 'produccion_dispensa', default: true },
      { clave: 'saldo_cc_bajo',    grupo: 'Pacientes', label: 'Saldo bajo',
        desc: 'La cuenta corriente (o el crédito en gramos) de un paciente quedó por debajo del umbral.',
        roles: %w[admin], feature: 'produccion_dispensa', default: true },
      { clave: 'plan_vence',       grupo: 'Cuenta', label: 'Plan por vencer',
        desc: 'Una semana antes y el día que vence.',
        roles: %w[admin], feature: nil, default: true },
      { clave: 'tarea_asignada',   grupo: 'Tareas', label: 'Tarea nueva asignada a vos',
        desc: 'Cuando alguien te asigna una tarea.',
        roles: EQUIPO, feature: nil, personal: false, default: true },
      { clave: 'tareas_del_dia',   grupo: 'Tareas', label: 'Resumen de tareas del día',
        desc: 'A las 8:00, cuántas tareas tenés para hoy.',
        roles: %w[cultivador], feature: nil, personal: true, default: true },
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
      d = tipo[:default]
      d.is_a?(String) ? club.feature?(d) : d == true
    end
  end
end
