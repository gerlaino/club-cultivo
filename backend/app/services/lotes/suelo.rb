module Lotes
  # «¿QUÉ COMIÓ ESTA FLOR?» — el suelo de un lote plantado en una cama de suelo vivo.
  #
  # En no-till lo que se le puso a la cama hace dos cosechas sigue en la tierra: por eso va TODA la
  # historia de la cama hasta que el lote se cosechó, con lo de su ciclo marcado (Germán, 25-sep,
  # D12). Cada aplicación con sus productos y cantidades (la copia que quedó al aplicar), la mezcla
  # con la que se armó y los análisis de suelo. Si una enmienda viene contaminada, desde acá se
  # sabe qué flores tocó.
  #
  # nil si el lote no creció en una cama.
  class Suelo
    def initialize(lote)
      @lote = lote
    end

    def call
      cama = @lote&.cama
      return nil if cama.nil?

      hasta = fecha_cosecha || Time.zone.today
      ciclo = @lote.cama_ciclo
      registros = cama.registros.includes(:user, :cama_ciclo)
                      .where('registrado_en <= ?', hasta.end_of_day).reorder(:registrado_en).to_a
      {
        cama: { id: cama.id, nombre: cama.nombre, m2: cama.m2&.to_f, armada_el: cama.armada_el,
                sala: cama.sala&.nombre },
        ciclo: ciclo && { numero: ciclo.numero, desde: ciclo.desde, hasta: ciclo.hasta },
        mezcla: cama.mezcla,
        hasta: hasta,
        # Los productos distintos que recibió la cama (lo que contesta la pregunta de un vistazo).
        productos: productos(registros),
        registros: registros.map { |r|
          CamaSerializer.registro(r).merge(del_ciclo: ciclo.present? && r.cama_ciclo_id == ciclo.id)
        },
        analisis: cama.analisis_suelo.where('fecha <= ?', hasta).map { |a| CamaSerializer.analisis(a) },
      }
    end

    private

    def fecha_cosecha
      ev = @lote.lote_eventos.where(tipo: 'cambio_estado', estado_nuevo: 'cosecha').order(:registrado_en).first
      ev&.registrado_en&.to_date
    end

    def productos(registros)
      registros.flat_map { |r| Array(r.nutricion.to_h['items']).map { |i| [i['nombre'], i['unidad'], i['descontado'].to_f, r] } }
               .group_by { |nombre, unidad, _, _| [nombre, unidad] }
               .map { |(nombre, unidad), filas|
                 { nombre: nombre, unidad: unidad, veces: filas.size,
                   cantidad: filas.sum { |f| f[2] }.round(3),
                   primera: filas.map { |f| f[3].registrado_en }.min, ultima: filas.map { |f| f[3].registrado_en }.max }
               }
               .sort_by { |p| p[:primera] }
    end
  end
end
