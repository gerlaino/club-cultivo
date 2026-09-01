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
    def initialize(mostrador:, desde: nil, hasta: nil)
      @mostradores = Array(mostrador)
      @mostrador   = @mostradores.first
      hoy    = Time.zone.today
      @desde = desde.presence ? Date.parse(desde.to_s) : hoy.beginning_of_month
      @hasta = hasta.presence ? Date.parse(hasta.to_s) : hoy
    end

    def call
      { resumen: resumen, por_producto: por_producto, por_turno: por_turno, sin_revisar: sin_revisar,
        # Sólo cuando se miran varias: con una sola, comparar contra sí misma es una fila vacía.
        por_sede: @mostradores.size > 1 ? por_sede : nil,
        # La pantalla muestra ESTE rango en sus campos, en vez de calcular uno propio.
        rango: { desde: @desde, hasta: @hasta } }
    end

    private

    def turnos
      @turnos ||= begin
        rel = TurnoMostrador.where(mostrador_id: @mostradores.map(&:id))
                            .cerrados.includes(:cerrado_por, :confirmado_por, mostrador: :sede)
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
          recibido_por: t.confirmado_por&.nombre_completo,
          dispensado:  its.sum { |i| i.cantidad_dispensada.to_d }.to_f.round(2),
          faltante:    faltante.to_f.round(3),
          faltante_ars: its.sum { |i| i.diferencia_cierre.to_d.negative? ? valor(i, i.diferencia_cierre) : 0 }.to_f.round(2),
          motivos:     its.filter_map(&:motivo_diferencia).uniq,
          # Lo que el que atendió corrigió al recibir: si aparece seguido, el que carga la mesa
          # está declarando mal y ese es el cuello de botella, no la merma.
          correcciones: TurnoMostradorMovimiento.where(turno_mostrador_item_id: its.map(&:id))
                                                .correcciones.count,
          revisado:    t.revisado_at.present?,
        }
      end
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

    # Los turnos con diferencia que el admin todavía no miró. Es una lista de trabajo, no una
    # lista de sospechosos: se marca revisado y se archiva.
    def sin_revisar
      por_turno.select { |t| t[:revisado] == false && t[:faltante].positive? }.size
    end
  end
end
