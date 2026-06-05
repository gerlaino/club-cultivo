class PesajeManicuraSerializer
  def self.serialize(pesaje, include_plantas: false)
    peso_calculado = pesaje.pesadas_plantas.loaded? \
      ? pesaje.pesadas_plantas.sum(&:peso_seco_g).to_d.round(2) \
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
