module Lotes
  # Desprende parte de un lote a un lote NUEVO: de 20 esquejes que prendieron, 10 van a maceta de
  # 3 L y 10 a 5 L. Desde ahí dejan de ser el mismo grupo —riego, frecuencia y trasplante distintos,
  # y la alerta de raíz enrollada da distinto para cada mitad—, así que no caben en un lote con un
  # solo `tamanio_maceta`: el dato le mentiría a la mitad de las plantas.
  #
  # NO es un split simétrico: el lote original SE QUEDA con el resto y conserva su historia. Nace un
  # hijo con las plantas separadas y código derivado (L-26-043 → L-26-043-B), para que el parentesco
  # se vea sin tener que leer un campo.
  #
  # QUÉ SE LLEVA EL HIJO: las plantas elegidas (con sus QR, fotos y actividades), la genética, el
  # origen, la planta madre y la MISMA `start_date` —enraizaron juntas, y si el hijo arrancara hoy
  # sus días de ciclo saldrían mal—. Los eventos del padre no se copian: son del padre, y el hijo
  # apunta a él con `lote_origen_id`.
  #
  # PLATA: ver `costo_heredado_ars` más abajo y la migración `DesprenderLotes`.
  class Desprender
    Result = Struct.new(:ok, :error, :lote_nuevo, keyword_init: true) do
      def ok? = ok
    end

    def self.call(**kwargs) = new(**kwargs).call

    # plant_ids: cuáles se van (con QR por planta, elegir CUÁLES importa — si el sistema las elige
    # solo, las etiquetas físicas dejan de coincidir con los datos). Si no vienen, se toman las
    # últimas `cantidad` sin trazas individuales.
    def initialize(lote:, usuario:, plant_ids: nil, cantidad: nil, tamanio_maceta: nil, motivo: nil)
      @lote           = lote
      @usuario        = usuario
      @plant_ids      = Array(plant_ids).map(&:to_i).uniq.presence
      @cantidad       = cantidad.presence&.to_i
      @tamanio_maceta = tamanio_maceta.presence&.to_d
      @motivo         = motivo.presence
    end

    def call
      vivas = @lote.plants.where.not(state: 'descartada')
      elegidas = seleccionar(vivas)
      return Result.new(ok: false, error: @error) if @error

      if elegidas.size >= vivas.count
        return Result.new(ok: false, error: 'No se puede desprender el lote entero: quedaría vacío. ' \
                                            'Si querés cambiarle la maceta a todo, editá el lote.')
      end

      hijo = nil
      ActiveRecord::Base.transaction do
        hijo = crear_hijo(vivas.count, elegidas.size)
        copiar_linea_de_tiempo(hijo)
        Plant.where(id: elegidas.map(&:id)).update_all(lote_id: hijo.id, updated_at: Time.current)
        # Separar un lote enraizando poniendo las plantas en maceta ES prenderlas: el hijo nace en
        # vegetativo (ver Lote#prender_al_ponerlo_en_maceta) y las plantas tienen que ir con él, o
        # quedan "enraizando" adentro de un lote en vegetativo.
        if hijo.estado != @lote.estado && (plant_state = Lote::FASE_A_PLANT_STATE[hijo.estado])
          Plant.where(id: elegidas.map(&:id)).update_all(state: plant_state, updated_at: Time.current)
        end
        recontar!(hijo)
        recontar!(@lote)
        registrar_eventos(hijo, elegidas.size)
      end

      # Fuera de la transacción: el costeo se deriva del libro y no debe abortar el desprendimiento.
      recalcular_costos(hijo)

      Result.new(ok: true, lote_nuevo: hijo)
    end

    private

    def seleccionar(vivas)
      if @plant_ids
        elegidas = vivas.where(id: @plant_ids).to_a
        if elegidas.size != @plant_ids.size
          @error = 'Algunas de las plantas elegidas no están en este lote (o están descartadas).'
        end
        return elegidas
      end

      return (@error = 'Indicá cuántas plantas se separan.') && [] if @cantidad.to_i < 1

      # Sin elección explícita, se van las últimas creadas: las de numeración más alta son las que
      # menos probablemente tengan una etiqueta ya pegada y anotada.
      elegidas = vivas.order(created_at: :desc, id: :desc).limit(@cantidad).to_a
      @error = "El lote tiene #{vivas.count} plantas vivas: no se pueden separar #{@cantidad}." if elegidas.size < @cantidad
      elegidas
    end

    def crear_hijo(total_vivas, cuantas)
      hijo = @lote.club.lotes.new(
        codigo:         proximo_codigo,
        sala_id:        @lote.sala_id,
        sede_id:        @lote.sede_id,
        genetica_id:    @lote.genetica_id,
        estado:         @lote.estado,
        origen:         @lote.origen,
        strain:         @lote.strain,
        planta_madre_id: @lote.planta_madre_id,
        # Enraizaron juntas: si el hijo arrancara hoy, sus días de ciclo y su enraizado saldrían mal.
        start_date:     @lote.start_date,
        grow_type:      @lote.grow_type,
        light_type:     @lote.light_type,
        fotoperiodo:    @lote.fotoperiodo,
        # Lo único que cambia a propósito (y el motivo de separarlas).
        tamanio_maceta: @tamanio_maceta || @lote.tamanio_maceta,
        dias_vegetativo_objetivo: @lote.dias_vegetativo_objetivo,
        dias_floracion_objetivo:  @lote.dias_floracion_objetivo,
        dias_cosecha_objetivo:    @lote.dias_cosecha_objetivo,
        lote_origen_id: @lote.id,
        split_at:       Time.current,
      )
      hijo.tamanio_maceta_inicial = @lote.tamanio_maceta_inicial if @lote.tamanio_maceta_inicial
      hijo.costo_heredado_ars     = repartir_costo(total_vivas, cuantas)
      hijo.save!
      @lote.update!(costo_cedido_ars: @lote.costo_cedido_ars.to_d + hijo.costo_heredado_ars)
      hijo
    end

    # Lo gastado hasta hoy es COMÚN a todas las plantas (mismo esqueje, mismo sustrato, misma luz),
    # así que se reparte por cabeza. Se congela en pesos y no como proporción a recalcular: lo que
    # se llevó es lo que se llevó el día que se separó, y así el número no se mueve solo cuando
    # después cambien las plantas o entren gastos nuevos.
    def repartir_costo(total_vivas, cuantas)
      return 0 if total_vivas.zero?
      acumulado = @lote.costo_lote&.costo_total.to_d + @lote.costo_heredado_ars.to_d - @lote.costo_cedido_ars.to_d
      return 0 if acumulado <= 0
      (acumulado * cuantas / total_vivas).round(2)
    end

    # L-26-043 → L-26-043-B, -C, … El sufijo muestra el parentesco de un vistazo.
    def proximo_codigo
      base = @lote.codigo.to_s.sub(/-([B-Z])\z/, '')   # desprender de un desprendido no encadena sufijos
      ('B'..'Z').each do |letra|
        candidato = "#{base}-#{letra}"
        return candidato unless @lote.club.lotes.exists?(codigo: candidato)
      end
      "#{base}-#{SecureRandom.hex(2)}"
    end

    # La historia hasta el desprendimiento es COMPARTIDA: las plantas que se van vivieron las mismas
    # fases el mismo día. Sin copiar los cambios de estado, el hijo se quedaba sin la fecha en que
    # entró a vegetativo y su ciclo se contaba desde el esqueje —30 días donde el padre marca 12—,
    # porque `fecha_inicio_vegetativo` cae a `start_date` cuando no encuentra el evento.
    def copiar_linea_de_tiempo(hijo)
      @lote.lote_eventos.where(tipo: 'cambio_estado').order(:registrado_en).each do |ev|
        hijo.lote_eventos.create!(
          tipo:            'cambio_estado',
          estado_anterior: ev.estado_anterior,
          estado_nuevo:    ev.estado_nuevo,
          descripcion:     ev.descripcion,
          registrado_en:   ev.registrado_en,
          user_id:         ev.user_id,
          club:            @lote.club,
        )
      end
    end

    def recontar!(lote)
      lote.update_column(:plants_count, lote.plants.where.not(state: 'descartada').count)
    end

    def registrar_eventos(hijo, cuantas)
      detalle = "#{cuantas} plantas separadas a #{hijo.codigo}"
      detalle += " · maceta #{@tamanio_maceta.to_f}L" if @tamanio_maceta
      detalle += " · #{@motivo}" if @motivo

      @lote.lote_eventos.create!(
        tipo: 'actividad', categoria: 'otro', descripcion: detalle,
        user: @usuario, club: @lote.club, registrado_en: Time.current,
      )
      hijo.lote_eventos.create!(
        tipo: 'actividad', categoria: 'otro',
        descripcion: "Desprendido de #{@lote.codigo} con #{cuantas} plantas" \
                     "#{@tamanio_maceta ? " · maceta #{@tamanio_maceta.to_f}L" : ''}" \
                     "#{hijo.costo_heredado_ars.to_d.positive? ? " · se lleva $#{hijo.costo_heredado_ars.to_f} de costo" : ''}",
        user: @usuario, club: @lote.club, registrado_en: Time.current,
      )

      # `copiar_linea_de_tiempo` trae la historia del padre, que llega hasta el enraizado. Si al
      # ponerlas en maceta el hijo prendió, ese salto es SUYO y arranca hoy: sin el evento, su
      # fecha de inicio de vegetativo cae a `start_date` y la analítica le cuenta días de más.
      if hijo.estado != @lote.estado
        hijo.lote_eventos.create!(
          tipo: 'cambio_estado', estado_anterior: @lote.estado, estado_nuevo: hijo.estado,
          descripcion: "Prendió al separarse: pasó a maceta de #{hijo.tamanio_maceta.to_f} L",
          user: @usuario, club: @lote.club, registrado_en: Time.current,
        )
      end
    end

    def recalcular_costos(hijo)
      CostoDesdeLibroService.new(lote: @lote.reload, actualizado_por: @usuario).call
      CostoDesdeLibroService.new(lote: hijo,          actualizado_por: @usuario).call
    rescue => e
      Rails.logger.error "[Lotes::Desprender] No se pudo recalcular el costo: #{e.message}"
    end
  end
end
