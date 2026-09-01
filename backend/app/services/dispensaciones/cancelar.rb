module Dispensaciones
  # Cancelar una dispensación CONSERVANDO el registro: revierte stock, cuenta corriente y asientos,
  # y deja el evento en el historial.
  #
  # Vivía entero adentro de `DispensacionesController#cancelar_entrega`. Se extrajo cuando la
  # rendición del repartidor necesitó lo mismo —el paquete que vuelve se cancela igual— porque la
  # alternativa era escribir la reversa dos veces, y dos reversas de la misma cosa dejan de
  # coincidir a la primera corrección.
  class Cancelar
    Result = Struct.new(:ok, :dispensacion, :error, keyword_init: true) do
      def ok? = ok
    end

    def self.call(**kwargs) = new(**kwargs).call

    def initialize(dispensacion:, usuario:, motivo: nil, evento: true)
      @d       = dispensacion
      @usuario = usuario
      @motivo  = motivo
      @evento  = evento
    end

    def call
      return err('La dispensación ya está cancelada') if @d.cancelada?
      if @d.movimientos_contables.any?(&:cerrado?)
        return err('Pertenece a un período contable cerrado y no puede cancelarse.')
      end

      ActiveRecord::Base.transaction do
        revertir_gramos
        revertir_cuenta_corriente
        CuentaCorrienteMovimiento.where(dispensacion_id: @d.id).update_all(dispensacion_id: nil)
        @d.movimientos_contables.destroy_all
        @d.cobros.destroy_all # los cobros (y sus comprobantes) se van con la cancelación
        @d.send(:incrementar_stock) # el producto vuelve al stock — y a la mesa, si sigue abierta
        registrar_evento if @evento
        @d.update!(estado_envio: 'cancelada', historial_envio: @d.historial_envio)
      end
      Result.new(ok: true, dispensacion: @d)
    rescue => e
      err(e.message)
    end

    private

    def err(msg) = Result.new(ok: false, error: msg)

    def registrar_evento
      @d.historial_envio = (@d.historial_envio || []) + [{
        estado: 'cancelado', at: Time.current.iso8601,
        por: @usuario&.nombre_completo, motivo: @motivo,
      }.compact.stringify_keys]
    end

    def revertir_cuenta_corriente
      cc = @d.paciente&.cuenta_corriente
      return unless cc

      # Revertir el neto que esta dispensa dejó en la CC (solo pesos; los gramos van por
      # `revertir_gramos`). Dos efectos posibles, opuestos:
      #   - débito → deuda por el faltante (bajó el saldo) → al revertir SUMA.
      #   - pago   → crédito por el excedente pagado de más (subió el saldo) → al revertir RESTA.
      movs     = cc.movimientos.where(dispensacion: @d).where("unidad IS NULL OR unidad = 'ars'")
      debitos  = movs.where(tipo: 'debito').sum(:monto).abs
      creditos = movs.where(tipo: 'pago').sum(:monto)
      delta    = debitos - creditos
      return if delta.zero?

      anterior = cc.saldo_disponible
      nuevo    = anterior + delta
      cc.update!(saldo_disponible: nuevo)
      cc.movimientos.create!(
        tipo: 'ajuste', monto: delta, saldo_anterior: anterior, saldo_nuevo: nuevo,
        descripcion: "Reversa dispensación ##{@d.id}", created_by: @usuario
      )
    end

    def revertir_gramos
      cc = @d.paciente&.cuenta_corriente
      return unless cc

      # Por unidad='gramos' (registros nuevos) o por descripción como fallback (los anteriores a
      # la migración).
      total_g = cc.movimientos.where(dispensacion: @d, tipo: 'debito')
                  .where("unidad = 'gramos' OR descripcion ILIKE ?", '%(crédito gramos)%')
                  .sum(:monto).abs
      return if total_g <= 0

      anterior = cc.saldo_disponible_g.to_d
      nuevo    = anterior + total_g
      cc.update!(saldo_disponible_g: nuevo)
      cc.movimientos.create!(
        tipo: 'ajuste', monto: total_g, saldo_anterior: anterior, saldo_nuevo: nuevo,
        descripcion: "Reversa dispensación ##{@d.id} (gramos)", created_by: @usuario
      )
    end
  end
end
