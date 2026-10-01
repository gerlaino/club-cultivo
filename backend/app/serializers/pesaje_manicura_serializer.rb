class PesajeManicuraSerializer
  def self.serialize(pesaje, include_plantas: false)
    # nil-safe: con includes, pesadas_plantas viene loaded y la suma corre en Ruby;
    # si alguna planta tiene peso_seco_g nil, sum(&:peso_seco_g) explotaría (0 + nil).
    peso_calculado = pesaje.pesadas_plantas.loaded? \
      ? pesaje.pesadas_plantas.sum { |pp| pp.peso_seco_g.to_d }.round(2) \
      : pesaje.pesadas_plantas.sum(:peso_seco_g).to_d.round(2)

    plantas_count_real = pesaje.pesadas_plantas.loaded? \
      ? pesaje.pesadas_plantas.size \
      : pesaje.pesadas_plantas.count

    result = {
      id:                pesaje.id,
      lote_id:           pesaje.lote_id,
      lote_codigo:       pesaje.lote&.codigo,
      lote_genetica:     pesaje.lote&.genetica&.nombre,
      manicurador_id:    pesaje.manicurador_id,
      manicurador_nombre: pesaje.manicurador&.nombre_completo || pesaje.manicurador&.email,
      club_id:           pesaje.club_id,
      stock_id:          pesaje.stock_id,
      fecha_pesaje:      pesaje.fecha_pesaje,
      estado:            pesaje.estado,
      peso_total_g:      pesaje.peso_total_g&.to_f,
      peso_calculado_g:  peso_calculado.to_f,
      peso_confirmado_g: pesaje.peso_confirmado_g&.to_f,
      plantas_count:     pesaje.plantas_count || plantas_count_real,
      plantas_registradas: plantas_count_real,
      # Qué plantas tiene esta jornada (la pantalla ofrece «Quitar» en las de la jornada abierta).
      plant_ids:         pesaje.pesadas_plantas.loaded? ? pesaje.pesadas_plantas.map(&:plant_id) : pesaje.pesadas_plantas.pluck(:plant_id),
      notas:             pesaje.notas,
      enviado_at:        pesaje.enviado_at,
      confirmado_at:     pesaje.confirmado_at,
      confirmado_por:    pesaje.confirmado_por&.nombre_completo,
      created_at:        pesaje.created_at,
    }

    if pesaje.stock
      result[:stock] = {
        id:                  pesaje.stock.id,
        numero_lote_producto: pesaje.stock.numero_lote_producto,
        cantidad:            pesaje.stock.cantidad.to_f,
        estado:              pesaje.stock.estado,
        sede_nombre:         pesaje.stock.sede&.nombre,
      }
    end

    # A qué frascos fue (uno, o varios si se repartió). Un pesaje viejo sin filas: su `stock`.
    if pesaje.confirmado?
      filas = pesaje.destinos.includes(:stock).to_a
      result[:destinos] = if filas.any?
        filas.map { |d| { stock_id: d.stock_id, numero: d.stock&.numero_lote_producto, descripcion: d.stock&.descripcion, gramos: d.gramos.to_f } }
      elsif pesaje.stock
        [{ stock_id: pesaje.stock_id, numero: pesaje.stock.numero_lote_producto, descripcion: pesaje.stock.descripcion, gramos: pesaje.peso_confirmado_g.to_f }]
      else
        []
      end
    end

    if include_plantas
      result[:plantas] = pesaje.pesadas_plantas.includes(:plant).map do |pp|
        {
          id:           pp.id,
          plant_id:     pp.plant_id,
          plant_nombre: pp.plant&.nombre,
          plant_qr:     pp.plant&.codigo_qr,
          peso_seco_g:  pp.peso_seco_g&.to_f,
          peso_humedo_g: pp.peso_humedo_g&.to_f,
        }
      end
    end

    result
  end
end
