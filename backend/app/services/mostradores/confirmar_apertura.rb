module Mostradores
  # La ENTREGA del mostrador: el que atiende recibe lo que dejó el admin.
  #
  # El admin declara "puse 300 g de Northern sobre la mesa" y el que va a atender dice "sí, están"
  # —o corrige—. Existe para que el arqueo del cierre mida algo: si no se confirma el punto de
  # partida, la diferencia de la noche mezcla lo que se consumió atendiendo con lo que nunca
  # estuvo sobre la mesa, y deja de servir para nada.
  #
  # No es un mecanismo de culpa: la merma es inevitable y el punto de contar es SABER CUÁNTA HAY,
  # para que la organización vea dónde se le va.
  #
  # Corregir NO es una pérdida: si el admin declaró 300 y hay 297, los otros 3 siguen en el
  # depósito, nunca salieron de la organización. Se corrige el reparto entre mesa y depósito y el
  # inventario no se toca. (El faltante de verdad aparece al CERRAR, contra lo que el mostrador
  # ya tenía confirmado.)
  class ConfirmarApertura
    Result = Struct.new(:ok, :turno, :error, keyword_init: true) do
      def ok? = ok
    end

    def self.call(**kwargs) = new(**kwargs).call

    # `correcciones`: [{ item_id:, contado:, motivo:, quitar: }] — sólo las que hagan falta.
    # `quitar: true` es para el producto que directamente NO ESTÁ: poner 0 lo dejaría en la mesa
    # en cero todo el día, ocupando lugar y pidiendo explicación cada vez que alguien lo mire.
    # `efectivo_contado`: lo que hay de verdad en el cajón. Se recibe la mesa Y la plata.
    def initialize(turno:, usuario:, correcciones: [], efectivo_contado: nil, motivo_efectivo: nil, notas: nil)
      @turno   = turno
      @usuario = usuario
      @correcciones = Array(correcciones).select { |c| c.respond_to?(:[]) && !c.is_a?(String) }
      @efectivo = efectivo_contado
      @motivo_efectivo = motivo_efectivo
      @notas   = notas
    end

    def call
      return err('El mostrador no está abierto') unless @turno&.abierto?
      return err('Este mostrador ya fue confirmado') if @turno.confirmado?
      # Quien cargó la mesa no puede recibírsela a sí mismo: serían dos firmas de la misma
      # persona, o sea ninguna. Si lo abre el que atiende ya nace confirmado (no hay entrega que
      # hacer); si lo abre el admin, tiene que recibirlo alguien más.
      if @usuario.id == @turno.abierto_por_id
        return err('Lo tiene que recibir quien vaya a atender, no quien cargó la mesa.')
      end

      ActiveRecord::Base.transaction do
        @correcciones.each { |c| aplicar!(c) }
        recibir_efectivo!
        @turno.update!(confirmado_por: @usuario, confirmado_at: Time.current,
                       notas_apertura: [@turno.notas_apertura, @notas.presence].compact.join(' · ').presence)
      end
      Result.new(ok: true, turno: @turno.reload)
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
      err(e.message)
    end

    private

    def err(msg) = Result.new(ok: false, error: msg)

    # La plata también se recibe. Si lo que hay no es lo que dice el sistema, el fondo pasa a ser
    # lo CONTADO —es lo que hay— y la diferencia queda asentada con quién la detectó y cuándo.
    #
    # Al revés que el stock, acá la diferencia SÍ es una pérdida real: los gramos que el admin
    # declaró de más siguen en el depósito, pero los pesos que faltan no están en ningún lado.
    def recibir_efectivo!
      caja = @turno.caja_turno
      return if caja.nil? || @efectivo.nil? || @efectivo.to_s.strip.empty?

      contado = @efectivo.to_d
      raise ArgumentError, 'El efectivo contado no puede ser negativo' if contado.negative?

      dif = contado - caja.efectivo_esperado_ars.to_d
      return if dif.abs < 0.01

      raise ArgumentError, 'Hay diferencia en la caja: escribí el motivo' if @motivo_efectivo.blank?

      # El fondo pasa a ser lo que realmente hay: si no, el cierre volvería a encontrar la misma
      # diferencia y la contaría dos veces.
      caja.update!(monto_inicial_ars: caja.monto_inicial_ars.to_d + dif)
      caja.movimientos_contables.create!(
        club: @turno.club, sede_id: caja.sede_id, created_by: @usuario,
        tipo: dif.negative? ? 'egreso' : 'ingreso', categoria: 'diferencia_caja',
        descripcion: "#{dif.negative? ? 'Faltante' : 'Sobrante'} al recibir el mostrador — " \
                     "#{@usuario.nombre_completo} — #{@motivo_efectivo}",
        monto_ars: dif.abs, fecha: Time.zone.today,
        pagado: true, medio_pago: 'efectivo', comprobante_tipo: 'sin_comprobante'
      )
    end

    def aplicar!(datos)
      item = @turno.items.find_by(id: (datos[:item_id] || datos['item_id']))
      raise ArgumentError, 'Ese producto no está en el mostrador' if item.nil?

      motivo  = (datos[:motivo] || datos['motivo']).presence
      quitar  = ActiveModel::Type::Boolean.new.cast(datos[:quitar] || datos['quitar'])
      contado = quitar ? 0.to_d : (datos[:contado] || datos['contado']).to_d
      raise ArgumentError, 'La cantidad contada no puede ser negativa' if contado.negative?

      dif = contado - item.esperado
      return if dif.zero? && !quitar

      raise ArgumentError, "#{item.stock&.etiqueta}: hay diferencia, escribí el motivo" if motivo.blank?

      # El producto que no está se saca de la mesa, no se deja en cero: un renglón en cero es un
      # pendiente eterno que hay que volver a explicar cada vez que alguien mira la pantalla.
      #
      # Sacarlo NO es borrar la fila. Borrarla se llevaba puesto, por `dependent: :destroy`, el
      # movimiento que acababa de escribir quién lo sacó y por qué — o sea, se perdía exactamente
      # lo que se quería guardar. La fila se queda sin un solo número y `en_la_mesa` deja de
      # listarla.
      if quitar
        raise ArgumentError, "#{item.stock&.etiqueta}: ya está en cero" if item.esperado.zero?

        item.movimientos.create!(club: @turno.club, usuario: @usuario, tipo: 'correccion',
                                 cantidad: -item.esperado, notas: "No estaba sobre la mesa — #{motivo}")
        return item.update!(cantidad_heredada: 0, cantidad_apertura: 0, cantidad_ajuste: 0)
      end

      # Corregir en MÁS no puede inventar mercadería: el techo es lo que quede libre abajo.
      if dif.positive? && dif > item.stock.cantidad_disponible_real.to_d
        raise ArgumentError,
              "No hay tanto de #{item.stock.etiqueta} en el depósito: " \
              "quedan #{item.stock.cantidad_disponible_real.round(2)} #{item.stock.unidad || 'g'}"
      end

      item.update!(cantidad_ajuste: item.cantidad_ajuste.to_d + dif)
      item.movimientos.create!(club: @turno.club, usuario: @usuario, tipo: 'correccion',
                               cantidad: dif, notas: motivo)
    end
  end
end
