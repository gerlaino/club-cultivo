module Mostradores
  # DÓNDE SE LE VA EL PRODUCTO a la organización.
  #
  # No es una auditoría ni un tablero de culpas: la merma es inevitable, y contarla sirve para
  # saber cuánta hay, en qué producto y en qué momento — que es lo que deja ver un cuello de
  # botella. Tres gramos por turno en flor seca no son un problema; treinta en prerolls, sí.
  #
  # El número que manda es el PORCENTAJE sobre lo entregado, no el absoluto: 3,6 g de merma sobre
  # 85 g dispensados es 4% y hay algo que mirar; los mismos 3,6 g sobre 850 g es 0,4% y es la
  # balanza. Un ranking por gramos absolutos siempre pone arriba al producto que más se vende, y
  # eso no dice nada.
  class Merma
    def self.call(**kwargs) = new(**kwargs).call

    # Sin fechas, el mes en curso — CALCULADO ACÁ, en la zona del servidor.
    #
    # Lo calculaba la pantalla, y el navegador puede estar en otra zona horaria que Rails: con el
    # cliente en UTC y el servidor en Buenos Aires, entre las 21:00 y las 00:00 el rango arrancaba
    # en un mañana donde todavía no había cerrado nadie y la solapa se veía vacía justo en el
    # horario en que se cierra el mostrador. El cliente no tiene por qué adivinar qué día es acá.
    # `mostrador` puede ser uno o VARIOS: con una sola sede a la vez no se puede contestar la
    # pregunta que encuentra el cuello de botella, que es "¿por qué en Centro se pierde el triple
    # que en Norte?". Comparar es el uso, no un extra.
    # `veredicto:` se apaga cuando quien llama es el propio `Veredicto` midiendo una ventana:
    # si no, cada medición pediría su propio veredicto y eso se llama a sí mismo para siempre.
    def initialize(mostrador:, desde: nil, hasta: nil, veredicto: true)
      @mostradores = Array(mostrador)
      @mostrador   = @mostradores.first
      hoy    = Time.zone.today
      @desde = desde.presence ? Date.parse(desde.to_s) : hoy.beginning_of_month
      @hasta = hasta.presence ? Date.parse(hasta.to_s) : hoy
      @con_veredicto = veredicto
    end

    def call
      { resumen: resumen, por_producto: por_producto, por_turno: por_turno, por_persona: por_persona,
        sin_revisar: sin_revisar,
        # Sólo cuando se miran varias: con una sola, comparar contra sí misma es una fila vacía.
        por_sede: @mostradores.size > 1 ? por_sede : nil,
        # ¿ESTÁ COMO SIEMPRE O CAMBIÓ ALGO? Un porcentaje solo no se compara con nada, y el
        # criterio ya existía —el aviso automático lo usa para interrumpir a alguien—; la pantalla
        # lo ignoraba. Va contra la ÚLTIMA SEMANA y no contra el rango elegido: es "cómo viene
        # ahora", y si cambiara con el filtro no se podría comparar con nada.
        veredicto: @con_veredicto ? Veredicto.call(mostrador: @mostradores) : nil,
        # La merma se entiende como TENDENCIA. El total del mes no dice si empeoró, y hasta ahora
        # la única forma de saberlo era cambiar el rango a mano y acordarse del número anterior.
        serie: serie,
        # La pantalla muestra ESTE rango en sus campos, en vez de calcular uno propio.
        rango: { desde: @desde, hasta: @hasta } }
    end

    private

    def turnos
      @turnos ||= begin
        rel = TurnoMostrador.where(mostrador_id: @mostradores.map(&:id))
                            .cerrados.includes(:cerrado_por, :abierto_por, mostrador: :sede)
        rel = rel.where('cerrado_at >= ?', @desde.beginning_of_day) if @desde
        rel = rel.where('cerrado_at <= ?', @hasta.end_of_day)       if @hasta
        rel.order(cerrado_at: :desc).to_a
      end
    end

    def items
      @items ||= TurnoMostradorItem.where(turno_mostrador_id: turnos.map(&:id))
                                   .includes(:stock).to_a
    end

    # Cuánto vale lo que no apareció. Sin esto la merma es un número de gramos que no se compara
    # con nada: en plata se puede poner al lado de cualquier otro gasto y decidir si vale la pena
    # hacer algo.
    def valor(item, cantidad) = (cantidad.abs * item.stock&.costo_unitario_ars.to_d)

    def resumen
      dispensado = items.sum { |i| i.cantidad_dispensada.to_d }
      faltante   = items.sum { |i| [i.diferencia_cierre.to_d, 0].min.abs }
      sobrante   = items.sum { |i| [i.diferencia_cierre.to_d, 0].max }
      {
        turnos:        turnos.size,
        dispensado:    dispensado.to_f.round(2),
        faltante:      faltante.to_f.round(3),
        sobrante:      sobrante.to_f.round(3),
        faltante_ars:  items.sum { |i| i.diferencia_cierre.to_d.negative? ? valor(i, i.diferencia_cierre) : 0 }.to_f.round(2),
        # Sobre lo ENTREGADO: es la única forma de comparar productos que se venden distinto.
        merma_pct:     dispensado.positive? ? ((faltante / dispensado) * 100).to_f.round(2) : nil,
      }
    end

    # Agrupado por producto (genética + forma), no por frasco: dos lotes de la misma variedad son
    # el mismo problema, y separarlos esconde la tendencia.
    def por_producto
      items.group_by { |i| i.stock&.etiqueta || '—' }.map do |etiqueta, its|
        dispensado = its.sum { |i| i.cantidad_dispensada.to_d }
        faltante   = its.sum { |i| [i.diferencia_cierre.to_d, 0].min.abs }
        {
          producto:   etiqueta,
          unidad:     its.first.stock&.unidad || 'g',
          dispensado: dispensado.to_f.round(2),
          faltante:   faltante.to_f.round(3),
          faltante_ars: its.sum { |i| i.diferencia_cierre.to_d.negative? ? valor(i, i.diferencia_cierre) : 0 }.to_f.round(2),
          merma_pct:  dispensado.positive? ? ((faltante / dispensado) * 100).to_f.round(2) : nil,
          turnos:     its.map(&:turno_mostrador_id).uniq.size,
        }
      # Por porcentaje, no por gramos: el ranking absoluto siempre encabeza con lo que más se
      # vende. Los que no tienen porcentaje (nada dispensado) van al final.
      end.sort_by { |p| -(p[:merma_pct] || -1) }
    end

    def por_turno
      por_turno_items = items.group_by(&:turno_mostrador_id)
      turnos.map do |t|
        its = por_turno_items[t.id] || []
        faltante = its.sum { |i| [i.diferencia_cierre.to_d, 0].min.abs }
        {
          id:          t.id,
          cerrado_at:  t.cerrado_at,
          cerrado_por: t.cerrado_por&.nombre_completo,
          # Quien ABRIÓ es quien contó la mesa al arrancar y quien atendió con ella: el arqueo es
          # suyo. Se llamaba `recibido_por` cuando había una recepción que firmar; ya no la hay.
          atendio: t.abierto_por&.nombre_completo,
          dispensado:  its.sum { |i| i.cantidad_dispensada.to_d }.to_f.round(2),
          faltante:    faltante.to_f.round(3),
          faltante_ars: its.sum { |i| i.diferencia_cierre.to_d.negative? ? valor(i, i.diferencia_cierre) : 0 }.to_f.round(2),
          # El % también acá: es el número que manda en los otros dos cortes, y sin él la misma
          # tabla diría cosas distintas según por dónde se la corte.
          merma_pct:   turno_pct(its),
          motivos:     its.filter_map(&:motivo_diferencia).uniq,
          # Cuántas veces quien abrió corrigió lo que decía la mesa. Si aparece seguido, el
          # cuello de botella no es la merma: es que la mesa se está declarando mal.
          correcciones: its.count { |i| i.diferencia_apertura.to_d.nonzero? },
          revisado:    t.revisado_at.present?,
          # Por qué está en la lista de trabajo. Un renglón que no dice qué mirar obliga a
          # abrirlo para descubrir que no era nada.
          motivos_revision: motivos_por_turno[t.id] || [],
        }
      end
    end

    # QUIÉN ATENDIÓ CADA TURNO, para saber dónde ajustar.
    #
    # El problema de un ranking de personas no es moral, es estadístico: quien más volumen mueve
    # encabeza siempre, y quien fracciona flor pierde más que quien entrega prerolls. Por eso la
    # fila no es sólo un porcentaje —
    #
    #   · `contra_promedio` compara con el promedio DEL MISMO MOSTRADOR en el MISMO período, que
    #     es el único número que dice "acá hay algo distinto" en vez de "acá se vende más";
    #   · `dispensado` va al lado, para que una fila de un turno no grite igual que una de veinte;
    #   · `suficientes` marca quién tiene turnos como para concluir algo. Debajo de ese piso el
    #     dato se muestra igual —esconderlo sería peor— pero sin conclusión.
    #
    # SE ATRIBUYE A QUIEN ATENDIÓ, que es quien ABRIÓ: la diferencia se produce durante la
    # jornada, no en el momento de contarla. Cuando cerró otra persona se dice (`cerro_otro`),
    # porque si no el admin lee un número de alguien que no hizo ese arqueo.
    TURNOS_PARA_CONCLUIR = 3

    def por_persona
      promedio = resumen[:merma_pct]
      por_turno_items = items.group_by(&:turno_mostrador_id)

      turnos.group_by { |t| t.abierto_por || t.cerrado_por }.filter_map do |persona, ts|
        next if persona.nil?

        its = ts.flat_map { |t| por_turno_items[t.id] || [] }
        dispensado = its.sum { |i| i.cantidad_dispensada.to_d }
        faltante   = its.sum { |i| [i.diferencia_cierre.to_d, 0].min.abs }
        pct        = dispensado.positive? ? ((faltante / dispensado) * 100).to_f.round(2) : nil
        {
          usuario_id:   persona.id,
          persona:      persona.nombre_completo,
          rol:          persona.role,
          turnos:       ts.size,
          dispensado:   dispensado.to_f.round(2),
          faltante:     faltante.to_f.round(3),
          faltante_ars: its.sum { |i| i.diferencia_cierre.to_d.negative? ? valor(i, i.diferencia_cierre) : 0 }.to_f.round(2),
          merma_pct:    pct,
          # En PUNTOS contra el promedio del período, no en veces: "el doble" de 0,2% no es nada.
          contra_promedio: (pct && promedio ? (pct - promedio).round(2) : nil),
          cerro_otro:   ts.count { |t| t.cerrado_por_id && t.cerrado_por_id != persona.id },
          suficientes:  ts.size >= TURNOS_PARA_CONCLUIR,
        }
      end.sort_by { |p| -(p[:merma_pct] || -1) }
    end

    # Sede contra sede: es la comparación que encuentra el cuello de botella. Si en una se pierde
    # el triple que en otra con el mismo producto, el problema no es la merma — es algo de esa
    # sede, y hasta que no se ponen al lado no se ve.
    def por_sede
      por_turno_items = items.group_by(&:turno_mostrador_id)
      turnos.group_by { |t| t.mostrador&.sede }.filter_map do |sede, ts|
        next if sede.nil?

        its = ts.flat_map { |t| por_turno_items[t.id] || [] }
        dispensado = its.sum { |i| i.cantidad_dispensada.to_d }
        faltante   = its.sum { |i| [i.diferencia_cierre.to_d, 0].min.abs }
        {
          sede_id:      sede.id,
          sede:         sede.nombre,
          turnos:       ts.size,
          dispensado:   dispensado.to_f.round(2),
          faltante:     faltante.to_f.round(3),
          faltante_ars: its.sum { |i| i.diferencia_cierre.to_d.negative? ? valor(i, i.diferencia_cierre) : 0 }.to_f.round(2),
          merma_pct:    dispensado.positive? ? ((faltante / dispensado) * 100).to_f.round(2) : nil,
        }
      end.sort_by { |s| -(s[:merma_pct] || -1) }
    end

    # Semana a semana del rango, para dibujar la tendencia. Se corta por semana y no por día
    # porque un mostrador cierra una o dos veces por jornada: en días, la mitad de las barras son
    # cero y el dibujo miente. Las semanas arrancan el lunes (`beginning_of_week`), que es como se
    # habla de una semana, y la última puede estar incompleta — por eso lleva su fecha.
    def serie
      por_semana = items.group_by { |i| turnos_por_id[i.turno_mostrador_id]&.cerrado_at&.to_date&.beginning_of_week }
      por_semana.compact.sort_by(&:first).map do |semana, its|
        dispensado = its.sum { |i| i.cantidad_dispensada.to_d }
        faltante   = its.sum { |i| [i.diferencia_cierre.to_d, 0].min.abs }
        {
          semana:     semana,
          turnos:     its.map(&:turno_mostrador_id).uniq.size,
          dispensado: dispensado.to_f.round(2),
          faltante:   faltante.to_f.round(3),
          faltante_ars: its.sum { |i| i.diferencia_cierre.to_d.negative? ? valor(i, i.diferencia_cierre) : 0 }.to_f.round(2),
          merma_pct:  dispensado.positive? ? ((faltante / dispensado) * 100).to_f.round(2) : nil,
        }
      end
    end

    def turnos_por_id = @turnos_por_id ||= turnos.index_by(&:id)

    def turno_pct(its)
      disp = its.sum { |i| i.cantidad_dispensada.to_d }
      return nil unless disp.positive?

      falt = its.sum { |i| [i.diferencia_cierre.to_d, 0].min.abs }
      ((falt / disp) * 100).to_f.round(2)
    end

    # Una sola consulta para todos los turnos del período — el mismo cálculo que usa el badge del
    # controller. No se vuelve a decidir acá qué cuenta como "pide una mirada".
    def motivos_por_turno
      @motivos_por_turno ||= Mostradores::MotivosDeRevision.por_turno(TurnoMostrador.where(id: turnos.map(&:id)))
    end

    # Los turnos que piden una mirada y el admin todavía no miró. Es una lista de trabajo, no una
    # lista de sospechosos: se marca revisado y se archiva.
    def sin_revisar
      por_turno.count { |t| t[:revisado] == false && t[:motivos_revision].any? }
    end
  end
end
