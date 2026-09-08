module Mostradores
  # Corregir el conteo de un turno YA CERRADO.
  #
  # Es el único lugar del módulo donde un dedazo destruye datos: escribir 21 en vez de 215 cierra
  # con un faltante de 194 g y **ajusta el inventario real**. La caja se puede anular; esto no
  # tenía vuelta atrás.
  #
  # No se reabre el turno ni se borra nada: el ajuste viejo queda y se asienta **la diferencia
  # entre lo que se había contado y lo que se cuenta ahora**. Borrar un movimiento de stock para
  # tapar un error es peor que el error — el rastro de que alguien corrigió es justamente lo que
  # hay que poder mostrar después.
  #
  # Corrige administración, no el mostrador: toca inventario de un turno que ya cerró.
  class CorregirCierre
    Result = Struct.new(:ok, :turno, :error, keyword_init: true) do
      def ok? = ok
    end

    def self.call(**kwargs) = new(**kwargs).call

    # `conteos`: [{ item_id:, contado: }] — sólo los que haya que corregir.
    # `efectivo_contado_ars`: la plata, si es ESA la que se cargó mal.
    def initialize(turno:, usuario:, conteos: [], motivo: nil, efectivo_contado_ars: nil)
      @turno    = turno
      @usuario  = usuario
      @conteos  = Array(conteos).select { |c| c.respond_to?(:[]) && !c.is_a?(String) }
      @motivo   = motivo
      @efectivo = efectivo_contado_ars
    end

    def call
      return err('Esa caja todavía no se cerró') unless @turno&.cerrado?
      return err('Escribí por qué se corrige el conteo') if @motivo.blank?
      return err('No hay nada que corregir') if @conteos.empty? && @efectivo.blank?

      ActiveRecord::Base.transaction do
        @conteos.each { |c| corregir!(c) }
        corregir_efectivo!
      end
      Result.new(ok: true, turno: @turno.reload)
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
      err(e.message)
    end

    private

    def err(msg) = Result.new(ok: false, error: msg)

    # LA PLATA TAMBIÉN SE CUENTA MAL, y hasta acá no se podía arreglar: la pantalla dejaba
    # corregir los gramos y el efectivo quedaba con el número equivocado para siempre — con su
    # asiento de faltante en el libro y su diferencia en el arqueo.
    #
    # MISMA REGLA QUE EL STOCK: no se borra el asiento viejo, se asienta LA DIFERENCIA. Borrar un
    # movimiento contable para tapar un error es peor que el error, y el rastro de que alguien
    # corrigió es justamente lo que hay que poder mostrar después.
    def corregir_efectivo!
      return if @efectivo.blank?

      caja = @turno.caja_turno
      raise ArgumentError, 'Este cierre no tiene caja' if caja.nil?

      nuevo = @efectivo.to_d
      raise ArgumentError, 'La plata contada no puede ser negativa' if nuevo.negative?

      viejo = caja.efectivo_declarado_ars.to_d
      return if nuevo == viejo

      dif_vieja = caja.diferencia_ars.to_d
      caja.update!(efectivo_declarado_ars: nuevo)
      delta = caja.reload.diferencia_ars.to_d - dif_vieja
      return if delta.abs < 0.01

      caja.movimientos_contables.create!(
        club:             caja.club,
        sede_id:          caja.sede_id,
        created_by:       @usuario,
        tipo:             delta.negative? ? 'egreso' : 'ingreso',
        categoria:        'diferencia_caja',
        descripcion:      "Corrección del arqueo — #{caja.sede&.nombre} " \
                          "(cierre del #{caja.cerrada_at&.to_date&.strftime('%d/%m/%Y')}): " \
                          "se había contado $#{viejo.round(2)} y había $#{nuevo.round(2)} — #{@motivo}",
        monto_ars:        delta.abs,
        fecha:            (caja.cerrada_at || Time.current).to_date,
        pagado:           true,
        medio_pago:       'efectivo',
        comprobante_tipo: 'sin_comprobante',
      )
    end

    # Lo que el cierre TENDRÍA que haber movido si se hubiera contado esto. Contra el esperado,
    # que es el número contra el que se arquea. (Sin esperado —ítems viejos, de antes de que se
    # guardara— no hay contra qué: se cae a la resta de siempre.)
    def efecto_corregido(item, nuevo)
      return nuevo - item.cantidad_cierre.to_d + item.efecto_en_inventario if item.esperado_cierre.nil?

      nuevo - item.esperado_cierre.to_d
    end

    def corregir!(datos)
      item = @turno.items.find_by(id: (datos[:item_id] || datos['item_id']))
      raise ArgumentError, 'Ese producto no está en ese cierre' if item.nil?

      nuevo = (datos[:contado] || datos['contado']).to_d
      raise ArgumentError, 'La cantidad contada no puede ser negativa' if nuevo.negative?

      return if nuevo == item.cantidad_cierre.to_d

      stock = item.stock
      raise ArgumentError, 'El producto ya no existe' if stock.nil?

      # SE CORRIGE CONTRA LO ESPERADO, NO CONTRA LO CONTADO.
      #
      # Restar lo viejo y sumar lo nuevo sólo funciona si lo viejo se había aplicado, y hay un
      # caso en que no: el sobrante de quien atiende queda ANOTADO y no mueve el inventario
      # (contar no crea producto de la nada). Con la resta ingenua, corregir un cierre de 1.000
      # —donde había 300— a los 100 reales restaba 900 g que nunca habían entrado, en vez de los
      # 200 que faltaron de verdad. Se calcula el efecto que corresponde AHORA y se le descuenta
      # el que se aplicó ENTONCES: si no se aplicó ninguno, entra entero.
      anterior = item.cantidad_cierre.to_d
      aplicado = item.efecto_en_inventario
      delta    = efecto_corregido(item, nuevo) - aplicado

      item.update!(cantidad_cierre: nuevo,
                   motivo_diferencia: [item.motivo_diferencia, "corregido: #{@motivo}"].compact.join(' · '))
      return if delta.zero?

      stock.with_lock do
        stock.update!(cantidad: [stock.cantidad.to_d + delta, 0].max)
        stock.stock_movimientos.create!(
          tipo: 'ajuste', gramos: delta, usuario: @usuario, turno_mostrador: @turno,
          notas: "Corrección del conteo del cierre ##{@turno.id} — se había contado " \
                 "#{anterior.to_f} y eran #{nuevo.to_f} #{stock.unidad || 'g'} — #{@motivo}"
        )
      end
      stock.reload.marcar_agotado_si_vacio!(usuario: @usuario)
    end
  end
end
