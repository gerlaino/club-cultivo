module Salas
  # DAR VUELTA UNA SALA ENTRE VEGETATIVO Y FLORACIÓN, arrastrando a los lotes de adentro.
  #
  # Es UNA regla para las DOS puertas —editar el `kind` de la sala y el botón «Cambiar fase»—:
  # estaban escritas dos veces y ya divergían (una pedía confirmación con la lista de lotes; la
  # otra, la que se toca a la mañana con el café en la mano, no pedía nada).
  #
  # IDA Y VUELTA NO SON SIMÉTRICAS (sep-2026, decisión de Germán):
  #   · vegetativo → floración es un AVANCE: el lote entra en 12/12 y empieza a contar días de
  #     floración. Queda un evento `cambio_estado`, como siempre.
  #   · floración → vegetativo con lotes adentro es DESHACER. Nadie revegeta a propósito una
  #     planta que ya recibió 12/12: una sala vuelve a vegetativo o vacía, o porque alguien se
  #     equivocó de botón. Tratarlo como avance dejaba al lote con un ciclo falso —«estuvo un día
  #     en floración y revegetó»— que después contamina los días por etapa, Plan vs real y la
  #     analítica de ciclos. Así que se BORRA el paso a floración: el evento que lo marcó (que es
  #     lo que define la fecha de inicio y los relojes), el estado de las plantas y las tareas
  #     automáticas de floración que sigan pendientes.
  #     Lo que NO se borra: fotos, notas, riegos y registros de esos días. Son hechos reales de la
  #     planta con la etiqueta que sea, y nadie los va a volver a cargar. Queda una nota en el
  #     lote diciendo que se deshizo, para que el rastro exista sin mover ningún reloj.
  #
  # Con lotes adentro, LAS DOS direcciones piden confirmación con la lista lote por lote y los
  # días que lleva cada uno: el error humano es simétrico (pasar a 12/12 un lote recién
  # trasplantado también es un error). Una sala vacía se da vuelta sin preguntar.
  class CambiarFase
    FASES = %w[vegetativo floracion].freeze

    Result = Struct.new(:ok, :sala, :nueva_fase, :lotes_afectados, :plantas_afectadas,
                        :tareas_canceladas, :error, :requiere_confirmacion, :detalle,
                        keyword_init: true) do
      def ok? = ok
    end

    def self.call(**kwargs) = new(**kwargs).call

    def initialize(sala:, nueva_fase:, usuario:, confirmado: false, origen: 'cambio de fase')
      @sala       = sala
      @nueva_fase = nueva_fase.to_s
      @usuario    = usuario
      @confirmado = confirmado
      @origen     = origen
    end

    def call
      fase_actual = @sala.kind.to_s
      return err('Solo las salas en vegetativo o floración pueden cambiar de fase') unless FASES.include?(fase_actual)
      return err("La fase tiene que ser vegetativo o floración") unless FASES.include?(@nueva_fase)
      return err("La sala ya está en #{@nueva_fase}") if @nueva_fase == fase_actual

      # La sala no se da vuelta con lotes enraizando adentro: 12/12 le daría 12 horas de oscuridad
      # a esquejes que necesitan luz casi continua. La regla protege A LA PLANTA.
      if @nueva_fase == 'floracion'
        enraizando = @sala.lotes.enraizando
        if enraizando.exists?
          codigos = enraizando.limit(5).pluck(:codigo).join(', ')
          return err("Esta sala tiene lotes enraizando (#{codigos}). En floración (12/12) los esquejes " \
                     'no prenden: movelos a otra sala antes de cambiar la fase.')
        end
      end

      lotes = @sala.lotes.where(estado: fase_actual).to_a

      if lotes.any? && !@confirmado
        return Result.new(ok: false, requiere_confirmacion: true, nueva_fase: @nueva_fase,
                          detalle: detalle_confirmacion(lotes, fase_actual),
                          error: mensaje_confirmacion(lotes))
      end

      plantas = 0
      tareas  = 0
      ActiveRecord::Base.transaction do
        # La SALA se da vuelta primero: es ella la que arrastra a los lotes. Al revés, cada lote
        # pasaba de fase mientras su sala todavía figuraba en la anterior, un estado intermedio
        # que no existe en la realidad (y que la validación sala↔estado rechaza).
        @sala.update!(kind: @nueva_fase)

        lotes.each do |lote|
          plantas += lote.plants.where(state: fase_actual).update_all(state: @nueva_fase)
          if deshace?
            tareas += deshacer_floracion!(lote)
          else
            avanzar!(lote, fase_actual)
          end
        end
      end

      Result.new(ok: true, sala: @sala.reload, nueva_fase: @nueva_fase, lotes_afectados: lotes.size,
                 plantas_afectadas: plantas, tareas_canceladas: tareas)
    rescue ActiveRecord::RecordInvalid => e
      err(e.record.errors.full_messages.join(', '))
    end

    private

    def deshace? = @nueva_fase == 'vegetativo'

    def err(msg) = Result.new(ok: false, error: msg)

    # ── IDA: un avance, con su evento ──────────────────────────────────────────────────────────
    def avanzar!(lote, fase_actual)
      lote.update!(estado: @nueva_fase)
      lote.lote_eventos.create!(
        tipo: 'cambio_estado', estado_anterior: fase_actual, estado_nuevo: @nueva_fase,
        descripcion: "Cambio de fase por #{@origen} de la sala #{@sala.nombre}: #{fase_actual} → #{@nueva_fase}",
        user: @usuario, club: @sala.club, registrado_en: Time.current
      )
    end

    # ── VUELTA: se deshace el paso a floración ─────────────────────────────────────────────────
    def deshacer_floracion!(lote)
      entrada = entrada_a_floracion(lote)
      desde   = entrada&.registrado_en
      dias    = desde ? (Date.current - desde.to_date).to_i : nil

      lote.update!(estado: 'vegetativo')
      # El evento que marcó la entrada es lo que define `fecha_inicio_floracion` y los días de
      # fase: sin él, el lote vuelve a contar desde su último paso a vegetativo, como si la
      # floración no hubiera existido.
      entrada&.destroy!
      canceladas = cancelar_tareas_de_floracion!(lote, desde)

      # El rastro, como NOTA: dice qué se deshizo sin mover ningún reloj.
      lote.lote_eventos.create!(
        tipo: 'nota',
        descripcion: "Se deshizo el paso a floración" \
                     "#{desde ? " del #{desde.to_date.strftime('%d/%m/%Y')}" : ''}" \
                     "#{dias ? " (#{dias} #{dias == 1 ? 'día' : 'días'})" : ''} " \
                     "por #{@origen} de la sala #{@sala.nombre}: el lote sigue en vegetativo" \
                     "#{canceladas.positive? ? ", y se cancelaron #{canceladas} tareas de floración pendientes" : ''}.",
        user: @usuario, club: @sala.club, registrado_en: Time.current
      )
      canceladas
    end

    def entrada_a_floracion(lote)
      lote.lote_eventos.where(tipo: 'cambio_estado', estado_nuevo: 'floracion')
          .order(registrado_en: :desc).first
    end

    # Las tareas que la app le sugirió al entrar en floración (`TareasAutoService`) y nadie hizo
    # todavía. No tienen marca de "automática": se las reconoce por el molde del que salieron y
    # por haber nacido con la floración. Las que alguien ya completó se quedan — se hicieron.
    def cancelar_tareas_de_floracion!(lote, desde)
      moldes = TareasAutoService::SUGERENCIAS['floracion']
      return 0 if moldes.blank?

      alcance = Tarea.where(lote_id: lote.id, estado: 'pendiente', titulo: moldes.map { |m| m[:titulo] })
      alcance = alcance.where('created_at >= ?', desde) if desde
      alcance.update_all(estado: 'cancelada', updated_at: Time.current)
    end

    # ── LO QUE SE LE MUESTRA ANTES DE CONFIRMAR ────────────────────────────────────────────────
    def detalle_confirmacion(lotes, fase_actual)
      moldes = TareasAutoService::SUGERENCIAS['floracion'].map { |m| m[:titulo] }
      lotes.map do |lote|
        desde = lote.lote_eventos.where(tipo: 'cambio_estado', estado_nuevo: fase_actual)
                    .order(registrado_en: :desc).first&.registrado_en&.to_date
        {
          id: lote.id, codigo: lote.codigo, genetica: lote.genetica&.nombre,
          estado_actual: fase_actual, estado_nuevo: @nueva_fase,
          plantas: lote.plants.where.not(state: %w[descartada cosechado]).count,
          dias_en_fase: desde ? (Date.current - desde).to_i : nil,
          tareas_a_cancelar: deshace? ? Tarea.where(lote_id: lote.id, estado: 'pendiente', titulo: moldes).count : 0,
        }
      end
    end

    def mensaje_confirmacion(lotes)
      n = lotes.size
      if deshace?
        "#{n} lote#{n == 1 ? '' : 's'} vuelve#{n == 1 ? '' : 'n'} a vegetativo como si nunca " \
          'hubiera pasado a floración.'
      else
        "Pasar la sala a floración cambia de fase a #{n} lote#{n == 1 ? '' : 's'} que est#{n == 1 ? 'á' : 'án'} adentro."
      end
    end
  end
end
