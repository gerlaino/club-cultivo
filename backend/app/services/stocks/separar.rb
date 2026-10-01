module Stocks
  # SEPARAR UN FRASCO EN VARIOS (Germán, 1-oct-2026): «pesé el lote entero, confirmé, se creó un
  # frasco, y ahora quiero separar los bajos de los copones». Cada frasco nuevo sale del original
  # —misma sede, mismo lote, misma genética, misma fecha de elaboración— con su nombre, sus gramos y
  # su precio; lo que no se separa queda en el original, que se puede renombrar («Copones»).
  #
  # La trazabilidad no se corta: es el mismo traslado que «Repartir a sede» (una `transferencia` en
  # cada punta, nombrándose entre sí), así el nuevo dice «fraccionado de ST-1» y el original «siguió
  # en ST-2», y la cuenta de cada uno cierra. No sale nada del inventario: cambia de frasco.
  #
  # Sólo se separa lo guardado y libre (`Stock#separable`): lo que está sobre la mesa, reservado o
  # apartado para un evento se queda en el original. Algo tiene que quedar en el original: separar
  # TODO es repartirlo, y para eso alcanza con renombrar.
  class Separar
    MAX = 10
    Resultado = Struct.new(:origen, :nuevos, keyword_init: true)

    def initialize(stock:, frascos:, usuario:, descripcion_origen: nil)
      @stock    = stock
      @usuario  = usuario
      @frascos  = Array(frascos).map { |f| f.respond_to?(:to_unsafe_h) ? f.to_unsafe_h : f.to_h }.map(&:symbolize_keys)
      @renombre = descripcion_origen
    end

    def call
      validar_lista!
      nuevos = []
      ActiveRecord::Base.transaction do
        @stock.lock!
        raise ArgumentError, 'El frasco está cerrado' if @stock.agotado?

        total = @frascos.sum { |f| f[:gramos] }
        libre = @stock.separable
        if total > libre
          raise ArgumentError, "Se pueden separar hasta #{libre.round(2).to_f} #{@stock.unidad}: lo demás está " \
                               'sobre la mesa, reservado o apartado para un evento, y se queda en este frasco'
        end
        if total >= @stock.cantidad.to_d
          raise ArgumentError, 'Algo tiene que quedar en este frasco: separá menos que el total (o renombralo)'
        end

        @frascos.each { |f| nuevos << separar_uno!(f, total) }
        @stock.update!(descripcion: @renombre.strip.presence) unless @renombre.nil?
      end
      Resultado.new(origen: @stock.reload, nuevos: nuevos)
    end

    private

    def validar_lista!
      raise ArgumentError, 'Agregá al menos un frasco nuevo' if @frascos.empty?
      raise ArgumentError, "Se puede separar en hasta #{MAX} frascos a la vez" if @frascos.size > MAX

      @frascos.map! do |f|
        g = f[:gramos].to_d
        raise ArgumentError, 'Cada frasco nuevo lleva su cantidad' unless g.positive?

        precio = f[:precio_sugerido_ars].presence&.to_d
        raise ArgumentError, 'El precio no puede ser negativo' if precio&.negative?

        { gramos: g, descripcion: f[:descripcion].to_s.strip.presence, precio: precio }
      end
    end

    def separar_uno!(f, _total)
      cantidad_total = @stock.cantidad.to_d
      consumido = @stock.lote_origen_consumido_g.present? ? (@stock.lote_origen_consumido_g * (f[:gramos] / cantidad_total)).round(2) : nil
      nuevo = Stock.new(
        club_id: @stock.club_id, lote_id: @stock.lote_id, pesada_id: @stock.pesada_id,
        origen: @stock.origen, forma_producto: @stock.forma_producto, unidad: @stock.unidad,
        cantidad: f[:gramos], sede_id: @stock.sede_id,
        estado: @stock.sede_id ? 'asignado' : 'pendiente_asignacion',
        costo_unitario_ars: @stock.costo_unitario_ars,
        precio_sugerido_ars: f[:precio] || @stock.precio_sugerido_ars,
        genetica_id: @stock.genetica_id, descripcion: f[:descripcion], proveedor: @stock.proveedor,
        disponibilidad: @stock.disponibilidad, fecha_elaboracion: @stock.fecha_elaboracion,
        fecha_vencimiento_est: @stock.fecha_vencimiento_est, lote_origen_consumido_g: consumido,
      )
      nuevo.es_split = true # no vuelve a descontar del origen: se descuenta acá
      nuevo.save!
      @stock.decrement!(:cantidad, f[:gramos])
      nombre = [nuevo.numero_lote_producto, f[:descripcion]].compact.join(' · ')
      @stock.stock_movimientos.create!(
        tipo: 'transferencia', gramos: -f[:gramos], sede_origen_id: @stock.sede_id, sede_destino_id: @stock.sede_id,
        stock_resultante: nuevo, usuario: @usuario, notas: "Separado a #{nombre}",
      )
      nuevo.stock_movimientos.create!(
        tipo: 'transferencia', gramos: f[:gramos], sede_origen_id: @stock.sede_id, sede_destino_id: @stock.sede_id,
        usuario: @usuario, notas: "Separado desde #{@stock.numero_lote_producto}",
      )
      nuevo
    end
  end
end
