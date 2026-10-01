module Manicura
  # QUÉ PUDO QUEDAR MAL EN LOS DATOS por los agujeros del pesaje de manicura que se cerraron el
  # 1-oct-2026. Sólo lee, salvo un caso (ver `corregir_trabadas!`). Lo usa
  # `rake manicura:diagnostico`; cada hallazgo dice qué pasó y qué hacer, para que lo decida
  # una persona: tocar stock o rendimientos a ciegas sería peor que el error.
  #
  #   1. doble_pesada     — una planta pesada en dos jornadas. Si las dos se confirmaron, su peso
  #                         entró dos veces al stock.
  #   2. trabadas         — plantas con peso pero sin pesada en un lote en manicura (se borró la
  #                         jornada): la pantalla no deja pesarlas y el lote no cierra.
  #   3. rendimiento      — lotes ya cerrados cuyo rendimiento no es la suma de sus pesajes
  #                         confirmados (se reajustó un pesaje después del cierre).
  #   4. agotado_con_peso — frascos marcados agotados que tienen producto (un pesaje confirmado en
  #                         un frasco vacío, o una dispensa anulada cuyo producto volvió): la lista
  #                         de stock los esconde. Se reabren a pedido (`corregir_agotados!`).
  #   5. no_es_flor       — pesajes confirmados que fueron a un frasco que no es de flor seca.
  class Diagnostico
    Resultado = Struct.new(:doble_pesada, :trabadas, :rendimiento, :agotado_con_peso, :no_es_flor, keyword_init: true) do
      def vacio? = to_h.values.all?(&:empty?)
    end

    def initialize(club_ids: nil)
      @club_ids = club_ids
    end

    def call
      Resultado.new(doble_pesada: doble_pesada, trabadas: trabadas, rendimiento: rendimiento,
                    agotado_con_peso: agotado_con_peso, no_es_flor: no_es_flor)
    end

    # El único arreglo automático: dejar SIN PESAR las plantas trabadas. Es lo mismo que hace hoy
    # borrar una jornada, no toca stock ni pesajes, y sin esto el lote no puede cerrar.
    def corregir_trabadas!
      ids = trabadas.map { |t| t[:plant_id] }
      Plant.unscoped.where(id: ids).update_all(peso_seco: nil, peso_humedo: nil, updated_at: Time.current)
      ids.size
    end

    # Reabre los frascos agotados que tienen producto, con la misma regla que la app desde el
    # 1-oct-2026 (`Stock#reabrir_si_tiene_producto!`): dejan de estar agotados y su lote, si se
    # había finalizado, vuelve a curado.
    def corregir_agotados!
      agotado_con_peso.each do |f|
        st = Stock.unscoped.find(f[:stock_id])
        ActsAsTenant.with_tenant(st.club) { st.reabrir_si_tiene_producto! }
      end.size
    end

    private

    def lotes
      rel = Lote.unscoped.where(deleted_at: nil)
      @club_ids ? rel.where(club_id: @club_ids) : rel
    end

    def con_jornada = PesadaPlanta.joins(:pesaje_manicura).where(pesajes_manicura: { lote_id: lotes.select(:id) })

    def doble_pesada
      repetidas = con_jornada.group(:plant_id).having('COUNT(DISTINCT pesadas_plantas.pesaje_manicura_id) > 1').pluck(:plant_id)
      PesadaPlanta.joins(:pesaje_manicura).includes(:plant, pesaje_manicura: :lote)
                  .where(plant_id: repetidas).group_by(&:plant_id).map do |plant_id, pps|
        confirmadas = pps.select { |pp| pp.pesaje_manicura.estado == 'confirmado' }
        lote = pps.first.pesaje_manicura.lote
        { club_id: lote.club_id, lote: lote.codigo, plant_id: plant_id, planta: pps.first.plant&.nombre,
          jornadas: pps.map { |pp| "#{pp.pesaje_manicura_id} (#{pp.pesaje_manicura.estado}, #{pp.peso_seco_g.to_f} g)" },
          gramos_de_mas: confirmadas.size > 1 ? confirmadas.drop(1).sum { |pp| pp.peso_seco_g.to_d }.to_f : 0.0 }
      end
    end

    def trabadas
      Plant.unscoped.where(deleted_at: nil, lote_id: lotes.where(estado: 'en_manicura').select(:id))
           .where.not(state: 'descartada').where('peso_seco > 0')
           .where.not(id: con_jornada.select(:plant_id)).includes(:lote)
           .map { |p| { club_id: p.lote.club_id, lote: p.lote.codigo, plant_id: p.id, planta: p.nombre, peso_seco: p.peso_seco.to_f } }
    end

    def rendimiento
      sumas = PesajeManicura.unscoped.where(estado: 'confirmado', lote_id: lotes.select(:id)).group(:lote_id).sum(:peso_confirmado_g)
      lotes.where(id: sumas.keys).where.not(estado: 'en_manicura').filter_map do |l|
        suma = sumas[l.id].to_d
        next if l.rendimiento_real_g.to_d == suma

        { club_id: l.club_id, lote: l.codigo, estado: l.estado, rendimiento: l.rendimiento_real_g.to_f, suma_pesajes: suma.to_f }
      end
    end

    # Cualquier frasco de lote, no sólo los de pesaje: la anulación de dispensas también los dejaba así.
    def agotado_con_peso
      Stock.unscoped.where(deleted_at: nil, lote_id: lotes.select(:id), estado: 'agotado').where('cantidad > 0')
           .map { |s| { club_id: s.club_id, stock_id: s.id, frasco: s.numero_lote_producto, cantidad: s.cantidad.to_f } }
    end

    def no_es_flor
      PesajeManicura.unscoped.where(estado: 'confirmado', lote_id: lotes.select(:id)).joins(:stock)
                    .where.not(stocks: { forma_producto: 'flor_seca' }).includes(:lote, :stock)
                    .map { |p| { club_id: p.club_id, lote: p.lote.codigo, pesaje_id: p.id, frasco: p.stock.numero_lote_producto, forma: p.stock.forma_producto, gramos: p.peso_confirmado_g.to_f } }
    end
  end
end
