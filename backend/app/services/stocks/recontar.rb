module Stocks
  # RECONTAR ES CONTAR LOS DOS LUGARES (22-oct-2026).
  #
  # El reconteo pedía «la cantidad exacta que tenés ahora» sin decir de dónde. Quien cuenta va al
  # depósito, pesa el frasco y escribe eso: el sistema lo tomaba como el TOTAL y la mesa —que sigue
  # arriba— quedaba con más que el frasco entero (22 stocks en prod, ST-26-0026: total 15, mesa 126).
  # Y desde (fu) era peor: el reconteo además bajaba la mesa, borrando producto que estaba.
  #
  # Ahora se cuenta lo que se ve en cada lugar: el depósito y cada mesa donde está el producto. El
  # total es la suma y lo calcula la máquina; nadie tiene que saber que «total = depósito + mesa».
  #
  # Un frasco de cosecha no gana gramos por un ajuste (22-sep, «un ajuste no crea producto»), con
  # UNA excepción: devolver lo que un reconteo anterior le sacó. Eso no es producto nuevo, es
  # deshacer un conteo mal hecho, y el tope (`Stock#reconteo_devolvible`) asegura que nunca pase de
  # lo que salió del pesaje.
  class Recontar
    Resultado = Struct.new(:ok, :error, :sin_cambios, keyword_init: true) do
      def ok? = ok
    end

    def self.call(**kw) = new(**kw).call

    # `mesas`: { mostrador_item_id => contado }. Cada mesa donde hoy hay producto tiene que venir.
    def initialize(stock:, usuario:, deposito:, motivo:, mesas: {})
      @stock    = stock
      @usuario  = usuario
      @deposito = deposito
      @motivo   = motivo.to_s.strip
      @mesas    = (mesas.respond_to?(:to_unsafe_h) ? mesas.to_unsafe_h : mesas.to_h).transform_keys(&:to_i)
    end

    def call
      return err('El motivo es obligatorio') if @motivo.blank?
      return err('Escribí cuánto hay en el depósito (0 si no queda nada)') if @deposito.blank?

      deposito = @deposito.to_d
      return err('Lo contado no puede ser negativo') if deposito.negative?

      sin_cambios = false
      ActiveRecord::Base.transaction do
        @stock.lock!
        items = MostradorItem.unscoped.where(stock_id: @stock.id).includes(:mostrador).to_a
        items.select! { |mi| mi.cantidad.to_d.positive? || @mesas.key?(mi.id) }
        faltan = items.reject { |mi| @mesas.key?(mi.id) }
        raise ArgumentError, 'Falta contar lo que está sobre la mesa' if faltan.any?

        contado_mesa = items.to_h { |mi| [mi, @mesas[mi.id].to_d] }
        raise ArgumentError, 'Lo contado no puede ser negativo' if contado_mesa.values.any?(&:negative?)

        nueva = deposito + contado_mesa.values.sum
        delta = nueva - @stock.cantidad.to_d
        cambia_mesa = contado_mesa.any? { |mi, c| c != mi.cantidad.to_d }
        if delta.zero? && !cambia_mesa
          sin_cambios = true
          next
        end

        if delta.positive? && @stock.regulatorio? && delta > @stock.reconteo_devolvible
          raise ArgumentError, tope_cosecha(delta)
        end

        registrar_total!(nueva, delta, deposito, contado_mesa) unless delta.zero?
        contado_mesa.each do |mi, c|
          dif = c - mi.cantidad.to_d
          next if dif.zero?

          mi.update!(cantidad: c)
          mi.movimientos.create!(club_id: mi.club_id, usuario: @usuario, tipo: 'ajuste', cantidad: dif,
                                 motivo: "Recuento del stock — #{@motivo}", turno_mostrador: mi.mostrador&.turno_abierto)
        end
      end
      Resultado.new(ok: true, sin_cambios: sin_cambios)
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
      err(e.message)
    end

    private

    def registrar_total!(nueva, delta, deposito, contado_mesa)
      detalle = "depósito #{fmt(deposito)}" + contado_mesa.map { |mi, c| " + mesa #{fmt(c)}" }.join
      @stock.stock_movimientos.create!(tipo: 'ajuste', gramos: delta, usuario: @usuario,
                                       notas: "[RECONTEO] #{@motivo} (#{detalle})")
      # El usuario viaja hasta el callback que cierra el lote: el evento de cierre necesita autor.
      @stock.usuario_movimiento = @usuario
      estaba_agotado = @stock.agotado?
      @stock.update!(cantidad: nueva, **(nueva.zero? ? { estado: 'agotado' } : {}))
      @stock.reabrir_si_tiene_producto!(usuario: @usuario) if estaba_agotado && nueva.positive?
    end

    def tope_cosecha(delta)
      devolvible = @stock.reconteo_devolvible
      base = "Con eso el frasco tendría #{fmt(delta)} #{unidad} más. En un frasco de cosecha los gramos salen del pesaje"
      if devolvible.positive?
        "#{base}: sólo puede volver lo que le sacaron reconteos anteriores (#{fmt(devolvible)} #{unidad}). " \
          'Volvé a pesar; si de verdad hay más, el pesaje del lote estaba mal (Manicura → reajustar peso).'
      else
        "#{base}. Si pesaste de más, corregilo en el lote (Manicura → reajustar peso)."
      end
    end

    def unidad = @stock.unidad || 'g'
    def fmt(x) = x.to_d.round(2).to_s('F').sub(/\.0\z/, '')
    def err(msg) = Resultado.new(ok: false, error: msg)
  end
end
