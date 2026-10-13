module Autocultivo
  # «Últimas acciones» del inicio del autocultivo (Germán, 12-oct-2026): lo último que se hizo en
  # el cultivo —riegos y lo aplicado, mediciones, trasplantes, cambios de fase, tareas hechas—
  # en una lista, con cuándo, dónde y quién. Sirve para ver de un vistazo si algo ya se cargó
  # (y no cargarlo dos veces) y para ir a la ficha.
  #
  # Cada fuente usa su fecha de los HECHOS (`registrado_en`, `occurred_at`, `fecha_completada`),
  # nunca `updated_at`.
  class UltimasAcciones
    TAREA_TITULO = {
      'riego' => 'Riego', 'nutricion' => 'Nutrición', 'poda' => 'Poda', 'defoliacion' => 'Defoliación',
      'scrog_lst' => 'SCROG/LST', 'revision_plagas' => 'Revisión de plagas', 'limpieza_sala' => 'Limpieza',
      'ajuste_luz' => 'Ajuste de luz', 'registro_ambiental' => 'Medición',
    }.freeze
    ACTIVIDAD_PLANTA = {
      'transplant' => 'Trasplante', 'registro_planta' => 'Registro de la planta', 'measurement' => 'Medición',
      'photo' => 'Foto', 'note' => 'Nota', 'pruning' => 'Poda', 'watering' => 'Riego',
      'fertilization' => 'Fertilización', 'harvest' => 'Cosecha', 'state_change' => 'Cambio de fase', 'other' => 'Actividad',
    }.freeze

    def initialize(usuario:, limite: 8)
      @usuario = usuario
      @club    = usuario.club
      @limite  = limite.to_i.clamp(1, 30)
    end

    def call
      (registros + actividades_de_planta + eventos + tareas)
        .sort_by { |a| -a[:fecha].to_f }.first(@limite)
        .map { |a| a.merge(fecha: a[:fecha].iso8601) }
    end

    private

    def lotes = @lotes ||= @club.lotes.merge(Lote.al_alcance_de(@usuario))
    def lote_ids = @lote_ids ||= lotes.pluck(:id)

    # Cómo nombrar el lugar de un lote: en autocultivo, sus plantas («P1, P2 y 3 más»); en una
    # organización, el código.
    def donde(lote)
      return lote.codigo unless @club.personal?

      nombres = (plantas_por_lote[lote.id] || [])
      # Ya cosechado no quedan plantas en pie: se nombra por la genética.
      return lote.genetica&.nombre || lote.strain.presence || lote.sala&.nombre || 'Tus plantas' if nombres.empty?

      nombres.size > 3 ? "#{nombres.first(3).join(', ')} y #{nombres.size - 3} más" : nombres.join(', ')
    end

    def plantas_por_lote
      @plantas_por_lote ||= Plant.where(lote_id: lote_ids).order(:nombre).pluck(:lote_id, :nombre)
                                 .group_by(&:first).transform_values { |v| v.map(&:last).compact }
    end

    def nutricion = @nutricion ||= Lotes::Nutricion.new(nil, con_costo: false)

    def registros
      RegistroAmbiental.where(lote_id: lote_ids).includes(:user, lote: %i[sala genetica]).order(registrado_en: :desc).limit(@limite).map do |r|
        tareas = Array(r.tareas_realizadas)
        titulo = tareas.filter_map { |t| TAREA_TITULO[t] }.join(' y ').presence || 'Registro'
        detalle = []
        detalle << nutricion.texto_de_copia(r.nutricion, r.lote_id, personal: @club.personal?) if r.nutricion.present?
        detalle << "#{Lotes::Nutricion.num(r.volumen_l)} L" if r.volumen_l.present? && r.nutricion.blank?
        detalle << "pH #{Lotes::Nutricion.num(r.ph)}" if r.ph.present?
        detalle << "EC #{Lotes::Nutricion.num(r.ec)}" if r.ec.present?
        detalle << r.observaciones if r.observaciones.present?
        { tipo: 'registro', fecha: r.registrado_en, titulo: titulo, donde: donde(r.lote),
          detalle: detalle.join(' · ').presence, usuario: r.user&.nombre_completo,
          ruta: r.lote.sala_id ? "/salas/#{r.lote.sala_id}" : "/lotes/#{r.lote_id}" }
      end
    end

    def actividades_de_planta
      PlantActivity.joins(:plant).where(plants: { lote_id: lote_ids }).includes(:user, :plant)
                   .order(occurred_at: :desc).limit(@limite).map do |a|
        { tipo: 'planta', fecha: a.occurred_at, titulo: ACTIVIDAD_PLANTA[a.activity_type] || 'Actividad',
          donde: a.plant.nombre.presence || a.plant.codigo_qr, detalle: a.description.presence,
          usuario: a.user&.nombre_completo, ruta: "/plantas/#{a.plant_id}" }
      end
    end

    def eventos
      LoteEvento.where(lote_id: lote_ids, tipo: %w[cambio_estado actividad]).includes(:user, lote: %i[sala genetica])
                .order(registrado_en: :desc).limit(@limite).map do |e|
        titulo = if e.tipo == 'cambio_estado'
                   "Pasó a #{Lote.etiqueta_estado(e.estado_nuevo, e.lote.origen)}"
                 else
                   LoteEvento::CATEGORIA_META.dig(e.categoria, 'label') || 'Actividad'
                 end
        { tipo: 'evento', fecha: e.registrado_en, titulo: titulo, donde: donde(e.lote),
          detalle: (e.descripcion if e.tipo == 'actividad').presence, usuario: e.user&.nombre_completo,
          ruta: e.lote.sala_id ? "/salas/#{e.lote.sala_id}" : "/lotes/#{e.lote_id}" }
      end
    end

    def tareas
      @club.tareas.where(estado: 'completada').where.not(fecha_completada: nil)
           .where('tareas.lote_id IN (:l) OR tareas.lote_id IS NULL', l: lote_ids)
           .includes(:asignada_a).order(fecha_completada: :desc).limit(@limite).map do |t|
        { tipo: 'tarea', fecha: t.fecha_completada, titulo: "Hecha: #{t.titulo}", donde: nil,
          detalle: t.notas_completado.presence, usuario: t.asignada_a&.nombre_completo, ruta: '/tareas' }
      end
    end
  end
end
