module Registros
  # Lo que el dictado propone y parece REPETIDO (Germán, 12-oct-2026: «al detectar una acción
  # repetida, deberíamos preguntar si se quieren hacer dos registros de la misma»). Marca, no
  # quita: puede ser a propósito (dos riegos en el día). La pantalla lo muestra en la tarjeta y
  # pregunta antes de guardar.
  #
  # Dos casos, con una regla fija y no a criterio del modelo (que puede decir «coincide con lo ya
  # registrado» y proponerlo igual, dos veces):
  #   · `repetida`: la misma acción, sobre el mismo lote o sala, con los mismos datos, ya está
  #     antes en la misma lista;
  #   · `ya_registrado`: hoy ya se registró lo mismo (por tarea: riego, poda…) en ese lote o en
  #     alguno de esa sala.
  class Repetidos
    TAREA_LABEL = {
      'riego' => 'un riego', 'nutricion' => 'una fertilización', 'poda' => 'una poda',
      'defoliacion' => 'una defoliación', 'scrog_lst' => 'un SCROG/LST', 'revision_plagas' => 'una revisión de plagas',
      'limpieza_sala' => 'una limpieza', 'ajuste_luz' => 'un ajuste de luz', 'registro_ambiental' => 'una medición',
    }.freeze
    # Lo que el backend agrega a la propuesta no cuenta para decidir si dos son iguales.
    IGNORAR = %w[tareas_cerrar_ids tareas_a_cerrar].freeze

    # resolver: ->(accion) { [lote_ids, etiqueta] } — a qué lotes apunta la acción (uno, o los de
    # una sala) y cómo nombrar el lugar. Lo provee el controller, que sabe qué ve cada usuario.
    def initialize(acciones:, club:, hoy: Time.zone.today, resolver:)
      @acciones = Array(acciones)
      @club     = club
      @hoy      = hoy
      @resolver = resolver
    end

    def anotar!
      vistas = {}
      @acciones.each do |accion|
        tipo  = accion['tipo'].to_s
        next unless tipo.start_with?('registro_ambiental')

        datos = accion['datos'].is_a?(Hash) ? accion['datos'] : {}
        clave = [tipo, accion['lote_codigo'], accion['sala_nombre'] || datos['sala_nombre'],
                 datos.except(*IGNORAR).sort.to_h].to_json
        accion['repetida'] = 'Está dos veces en lo que dictaste.' if vistas[clave]
        vistas[clave] = true

        ya = ya_registrado(accion, datos)
        accion['ya_registrado'] = ya if ya
      end
      @acciones
    end

    private

    def ya_registrado(accion, datos)
      tareas = Array(datos['tareas_realizadas']).map(&:to_s) & TAREA_LABEL.keys
      return nil if tareas.empty?

      lote_ids, lugar = @resolver.call(accion)
      return nil if lote_ids.blank?

      # `registrado_en`: cuándo pasó (lo que se carga tarde se carga con su hora), no cuándo se tipeó.
      previo = RegistroAmbiental.where(lote_id: lote_ids, registrado_en: @hoy.all_day)
                                .where('tareas_realizadas ?| array[:t]', t: tareas)
                                .includes(:user).order(registrado_en: :desc).first
      return nil unless previo

      coincide = (Array(previo.tareas_realizadas) & tareas).first
      quien = previo.user&.nombre_completo.presence
      "Hoy ya se registró #{TAREA_LABEL[coincide]} en #{lugar} a las #{previo.registrado_en.in_time_zone.strftime('%H:%M')}" \
        "#{quien ? " (#{quien})" : ''}."
    end
  end
end
