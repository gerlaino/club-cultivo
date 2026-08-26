module Caja
  # Cierra un retiro de caja y decide, recién ahí, qué fue contablemente.
  #
  # El retiro nace NEUTRO (`ajuste`): cuando alguien saca plata del cajón todavía no está decidido
  # si la devuelve, trae la factura o se la descuentan. Asentarlo como egreso de entrada obligaría
  # a deshacer un asiento cada vez que la realidad resulta otra.
  #
  #   devuelto    → la plata vuelve al cajón. No hay gasto: el retiro se compensa, neto cero. Se
  #                 registra como devolución para que el arqueo del turno EN CURSO la espere.
  #   comprobante → se convierte en un egreso real, con la categoría de lo que se compró.
  #   sueldo      → egreso de sueldo. Es el "adelanto", pero decidido al cerrar.
  #
  # El saldo de cada persona NO se guarda en ningún lado: sale de sumar sus retiros sin saldar.
  class SaldarRetiro
    FORMAS = %w[devuelto comprobante sueldo].freeze

    Result = Struct.new(:ok, :retiro, :movimiento, :error, keyword_init: true) do
      def ok? = ok
    end

    def self.call(**kwargs) = new(**kwargs).call

    def initialize(retiro:, usuario:, forma:, categoria: nil, notas: nil)
      @retiro    = retiro
      @usuario   = usuario
      @forma     = forma.to_s
      @categoria = categoria.to_s.presence
      @notas     = notas.to_s.strip.presence
    end

    def call
      if (msg = validar)
        return Result.new(ok: false, error: msg)
      end

      generado = nil
      ActiveRecord::Base.transaction do
        generado = crear_movimiento!
        @retiro.update!(
          saldado_at:     Time.current,
          saldado_como:   @forma,
          saldado_por:    @usuario,
          salda_a:        generado,
        )
      end

      Result.new(ok: true, retiro: @retiro.reload, movimiento: generado)
    rescue => e
      Result.new(ok: false, error: e.message)
    end

    private

    def validar
      return 'Este movimiento no es un retiro de caja.' unless @retiro.categoria == 'retiro_caja'
      return 'Este retiro ya estaba saldado.'           if @retiro.saldado_at.present?
      return 'Indicá cómo se salda el retiro.'          unless FORMAS.include?(@forma)

      if @forma == 'comprobante' && !MovimientoContable::CATEGORIAS.include?(@categoria.to_s)
        return 'Elegí la categoría del gasto.'
      end
      nil
    end

    def crear_movimiento!
      case @forma
      when 'devuelto'    then movimiento_devolucion!
      when 'comprobante' then movimiento_egreso!(@categoria, 'Gasto rendido')
      when 'sueldo'      then movimiento_egreso!('sueldo', 'Descontado del sueldo')
      end
    end

    # La plata vuelve al cajón. Va contra la caja ABIERTA HOY, no contra la del turno del retiro:
    # ese turno ya cerró y su arqueo ya se hizo. La devolución la tiene que esperar el turno que
    # está corriendo, que es donde la plata reaparece.
    def movimiento_devolucion!
      base(
        tipo:        'ajuste',
        categoria:   'devolucion_caja',
        descripcion: "Devolución de retiro — #{quien} — #{motivo_original}",
        caja_turno:  caja_abierta,
      )
    end

    def movimiento_egreso!(categoria, prefijo)
      base(
        tipo:        'egreso',
        categoria:   categoria,
        descripcion: "#{prefijo} — #{quien} — #{@notas || motivo_original}",
        # Sin caja: el egreso no vuelve al cajón. La plata ya salió con el retiro y el arqueo de
        # aquel turno ya la descontó; sumarla acá la descontaría dos veces.
        caja_turno:  nil,
      )
    end

    def base(tipo:, categoria:, descripcion:, caja_turno:)
      MovimientoContable.create!(
        club:             @retiro.club,
        sede_id:          @retiro.sede_id,
        created_by:       @usuario,
        caja_turno:       caja_turno,
        salda_a:          @retiro,
        tipo:             tipo,
        categoria:        categoria,
        descripcion:      descripcion,
        monto_ars:        @retiro.monto_ars,
        fecha:            Time.zone.today,
        pagado:           true,
        medio_pago:       'efectivo',
        comprobante_tipo: 'sin_comprobante',
      )
    end

    def quien = @retiro.retirado_por&.nombre_completo || '—'

    def motivo_original = @retiro.descripcion.to_s.sub(/\A[^—]*—\s*/, '')

    # `unscoped` y no `without_tenant`: este servicio corre desde el panel del admin y
    # `without_tenant` toca estado global, que se filtra entre ejemplos.
    def caja_abierta
      return nil if @retiro.sede_id.nil?

      CajaTurno.unscoped.where(club_id: @retiro.club_id, punto_type: 'Sede',
                               punto_id: @retiro.sede_id, estado: 'abierta').first
    end
  end
end
