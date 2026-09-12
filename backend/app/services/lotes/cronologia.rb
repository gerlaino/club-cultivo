module Lotes
  # LA CRONOLOGÍA DE UN LOTE: cada cambio de estado con los días que llevó el anterior, las
  # plantas descartadas cuando se descartaron, y los pesajes. La leen la trazabilidad de un
  # frasco (con los pesajes de ESE frasco) y la de un lote (con todos los suyos).
  class Cronologia
    def initialize(lote, pesajes: nil, pesada: nil, plantas_count: nil)
      @lote          = lote
      @pesajes       = pesajes
      @pesada        = pesada
      @plantas_count = plantas_count
    end

    def call
      return [] unless @lote

      items = []
      cambios = @lote.lote_eventos.where(tipo: 'cambio_estado').order(:registrado_en).to_a
      cambios.each_with_index do |ev, i|
        anterior = cambios[i - 1] if i.positive?
        dias = anterior && (ev.registrado_en.to_date - anterior.registrado_en.to_date).to_i
        items << {
          fecha:   ev.registrado_en,
          tipo:    'estado',
          estado:  ev.estado_nuevo,
          titulo:  ev.estado_nuevo,
          detalle: [ev.sala_destino&.nombre,
                    dias && anterior && "#{dias} días en #{anterior.estado_nuevo}"].compact.join(' · ').presence,
        }
      end

      # No hay columna de fecha de descarte: queda en la actividad de la planta.
      PlantActivity.where(plant_id: @lote.plants.select(:id), activity_type: 'state_change')
                   .where("description ILIKE 'Descartada%'").includes(:plant).order(:occurred_at).each do |a|
        items << { fecha: a.occurred_at, tipo: 'descarte', titulo: 'Descartada 1 planta',
                   detalle: [a.plant&.nombre || a.plant&.codigo_qr, a.plant&.motivo_descarte].compact.join(' · ').presence }
      end

      (@pesajes || @lote.pesajes_manicura.confirmados).order(:fecha_pesaje).each do |pj|
        items << { fecha: pj.confirmado_at || pj.fecha_pesaje, tipo: 'pesaje',
                   titulo: "Pesaje de manicura · #{pj.peso_confirmado_g.to_f.round(1)} g",
                   detalle: [pj.plantas_count && "#{pj.plantas_count} plantas", pj.stock&.numero_lote_producto].compact.join(' · ').presence }
      end
      if @pesada
        items << { fecha: @pesada.registrado_at, tipo: 'pesaje',
                   titulo: "Pesada · #{@pesada.peso_total_g.to_f.round(1)} g",
                   detalle: @plantas_count.to_i.positive? ? "#{@plantas_count} plantas" : nil }
      end

      items.sort_by { |i| i[:fecha] || Time.zone.at(0) }
    end
  end
end
