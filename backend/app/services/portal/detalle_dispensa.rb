# EL DETALLE DE UNA DISPENSA, PARA EL PACIENTE (27-oct-2026, Germán: «cada dispensa debería tener
# su detalle, desde donde se podría llegar a la genética y a la trazabilidad del lote del stock
# dispensado, algo realmente profesional»).
#
# Es la trazabilidad de los frascos de los que salió lo que se llevó, recortada a lo que es SUYO y
# le sirve: de qué lote, por qué etapas pasó y cuándo, qué análisis dio, qué recibió el cultivo.
# No reusa `Stocks::Trazabilidad` entero a propósito: esa trae las entregas del frasco a OTROS
# pacientes, el costo y la cuenta de la mercadería. De ella se toman las piezas que no dicen nada
# de nadie más (`Lotes::Cronologia`, `Lotes::ResumenAplicaciones`, los análisis).
#
# Lo que dice el paciente vive en otro lado: la reseña la carga por el pasaporte (`/d/:token`).
module Portal
  class DetalleDispensa
    FORMAS = {
      'flor_seca' => 'Flor seca', 'hash' => 'Hash', 'aceite' => 'Aceite', 'tintura' => 'Tintura',
      'crema' => 'Crema', 'capsula' => 'Cápsulas', 'comestible' => 'Comestible', 'prensado' => 'Prensado',
      'preroll' => 'Preroll', 'otro' => 'Otro', 'externo' => 'Producto',
    }.freeze
    MEDIOS = {
      'efectivo' => 'Efectivo', 'transferencia' => 'Transferencia',
      'saldo_a_favor' => 'De tu saldo a favor', 'cuenta_corriente' => 'A tu cuenta corriente',
    }.freeze
    ORIGENES = { 'semilla' => 'De semilla', 'esqueje' => 'De esqueje' }.freeze

    def initialize(dispensa, url_helper: nil)
      @d   = dispensa
      @url = url_helper
    end

    def resumen
      {
        id:        @d.id,
        numero:    format('%04d', @d.id),
        fecha:     @d.fecha_dispensacion,
        sede:      @d.sede&.nombre,
        total:     @d.aporte_socio_ars.to_f,
        anulada:   @d.anulada_at.present?,
        con_envio: @d.con_envio,
        items:     items_vivos.map { |i| { nombre: nombre_de(i), cantidad: i.cantidad.to_f, unidad: unidad_de(i), lote: lote_de(i)&.codigo || i.lote_codigo } },
      }
    end

    def call
      resumen.merge(
        hora:      @d.created_at,
        envio:     @d.con_envio ? { estado: @d.estado_envio, costo: @d.costo_envio_ars&.to_f, entregado_at: @d.entregado_at } : nil,
        descuento: descuento,
        pagos:     pagos,
        # El pasaporte (`/d/:token`) es lo que abre el QR de la etiqueta del frasco.
        token:     @d.token,
        items:     items_vivos.map { |i| item(i) },
      )
    end

    private

    def items_vivos = @items_vivos ||= @d.items.includes(stock: [:genetica, { lote: %i[genetica sala] }]).to_a

    def nombre_de(item)
      item.genetica_nombre.presence || item.stock&.genetica&.nombre || FORMAS.fetch(item.stock&.forma_producto, 'Producto')
    end

    def unidad_de(item) = item.stock&.unidad.presence || 'g'

    def lote_de(item) = item.stock&.lote

    def descuento
      ars = @d.descuento_dispensa_ars.to_f
      pct = @d.descuento_dispensa_pct.to_f + @d.descuento_paciente_pct.to_f
      return nil if ars.zero? && pct.zero?

      { ars: ars.positive? ? ars : nil, pct: pct.positive? ? pct : nil }
    end

    # Cómo pagó. De los cobros; una dispensa vieja sin cobros cae al medio que quedó guardado.
    def pagos
      cobros = @d.cobros.to_a
      if cobros.empty?
        return [] if @d.aporte_socio_ars.to_f.zero?

        return [{ medio: MEDIOS.fetch(@d.medio_pago, @d.medio_pago.to_s.humanize), monto: @d.aporte_socio_ars.to_f }]
      end

      cobros.group_by(&:medio).map do |medio, cs|
        { medio: MEDIOS.fetch(medio, medio.to_s.humanize), monto: cs.sum { |c| c.monto_ars.to_f } }
      end
    end

    def item(item)
      stock    = item.stock
      lote     = lote_de(item)
      genetica = stock&.genetica || lote&.genetica
      {
        # «Volver a pedir lo mismo» (28-oct-2026): Reservar busca este producto en la mesa de hoy.
        stock_id: item.stock_id,
        nombre:   nombre_de(item),
        forma:    FORMAS.fetch(stock&.forma_producto, 'Producto'),
        cantidad: item.cantidad.to_f,
        unidad:   unidad_de(item),
        precio:   item.precio_unitario_ars && (item.precio_unitario_ars.to_f * item.cantidad.to_f).round(2),
        frasco:   stock && { numero: stock.numero_lote_producto, elaborado: stock.fecha_elaboracion },
        # El id sólo si la organización le muestra esa genética: el link no lleva a un 404.
        genetica: genetica && {
          id: genetica.visible_paciente? ? genetica.id : nil, nombre: genetica.nombre,
          tipo: genetica.tipo, thc: genetica.thc&.to_f, cbd: genetica.cbd&.to_f,
        },
        lote:     lote && lote_json(lote, stock),
        mi_resena: resena(genetica),
      }
    end

    def lote_json(lote, stock)
      aplicaciones = Lotes::ResumenAplicaciones.new(lote).call
      analisis = lote.analisis_laboratorio.order(fecha_analisis: :desc).first
      nutricion = Array(aplicaciones.dig(:nutricion, :productos)) + Array(aplicaciones.dig(:suelo, :productos))
      {
        codigo:   lote.codigo,
        origen:   ORIGENES[lote.origen],
        plantas:  lote.plants_count_cosechadas.presence || lote.plants_count,
        sala:     lote.sala&.nombre,
        etapas:   etapas(lote, stock),
        analisis: analisis && {
          fecha: analisis.fecha_analisis, laboratorio: analisis.laboratorio, thc: analisis.thc_pct&.to_f,
          cbd: analisis.cbd_pct&.to_f, cbg: analisis.cbg_pct&.to_f, terpenos: analisis.terpenos_principales,
        },
        nutricion:      nutricion.compact.uniq,
        suelo_vivo:     aplicaciones[:suelo].present?,
        # Lo que se le aplicó contra plagas u hongos, con su carencia. Vacío = no se le aplicó nada,
        # que también es información (la pantalla lo dice).
        fitosanitarios: Array(aplicaciones[:fitosanitarios]).map { |f| f.slice(:fecha, :producto, :motivo, :carencia_dias) },
      }
    end

    # Las etapas del lote con su fecha, su sala y cuánto duró cada una; el pesaje en seco de ESTE
    # frasco, el envasado y la entrega. Sin los descartes de plantas: son la operación de la
    # organización, no la historia de su flor.
    def etapas(lote, stock)
      cambios = lote.lote_eventos.where(tipo: 'cambio_estado').includes(:sala_destino).order(:registrado_en).to_a
      lista = cambios.each_with_index.map do |ev, i|
        siguiente = cambios[i + 1]
        dias = siguiente && (siguiente.registrado_en.to_date - ev.registrado_en.to_date).to_i
        detalle = [ev.sala_destino&.nombre, dias&.positive? && "#{dias} #{dias == 1 ? 'día' : 'días'}"].select(&:present?).join(' · ')
        { etapa: Lote.etiqueta_estado(ev.estado_nuevo, lote.origen), fecha: ev.registrado_en, detalle: detalle.presence }
      end
      if stock
        PesajeManicura.confirmados.where(id: stock.pesajes_manicura.select(:id)).order(:fecha_pesaje).each do |pj|
          lista << { etapa: 'Pesado en seco', fecha: pj.confirmado_at || pj.fecha_pesaje,
                     detalle: "#{pj.peso_confirmado_g.to_f.round(1).to_s.sub(/\.0\z/, '')} g" }
        end
        lista << { etapa: 'Envasado', fecha: stock.fecha_elaboracion, detalle: "Frasco #{stock.numero_lote_producto}" } if stock.fecha_elaboracion
      end
      lista.sort_by! { |e| e[:fecha].to_s }
      lista << { etapa: 'Te lo entregaron', fecha: @d.fecha_dispensacion, es_entrega: true,
                 detalle: [@d.sede&.nombre, "dispensa ##{format('%04d', @d.id)}"].compact.join(' · ') }
      lista
    end

    def resena(genetica)
      return nil unless genetica

      r = ResenaProducto.find_by(dispensacion_id: @d.id, genetica_id: genetica.id)
      r && { estrellas: r.estrellas, comentario: r.comentario }
    end
  end
end
