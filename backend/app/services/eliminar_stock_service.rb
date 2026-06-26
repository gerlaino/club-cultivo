# Borra un stock Y EN CASCADA sus derivados (los productos elaborados a partir de él),
# arrastrando lo REVERSIBLE (reservas y dispensaciones pendientes, con su rollback de stock /
# cuenta corriente / contabilidad). Bloquea TODO el borrado si en el stock o en cualquiera de
# sus derivados hay algo que no se puede deshacer sin romper plata/regulatorio:
#   - dispensaciones de delivery ya ENTREGADAS
#   - dispensaciones en un período contable CERRADO
#   - reservas con seña cobrada
class EliminarStockService
  class Bloqueado < StandardError; end

  def initialize(stock:, usuario:)
    @stock   = stock
    @usuario = usuario
  end

  def eliminar!
    validar! # valida el stock y todo su árbol de derivados ANTES de tocar nada
    ActiveRecord::Base.transaction do
      eliminar_recursivo(@stock)
    end
  end

  private

  # Borra un stock y, primero, sus derivados (en profundidad), con la misma reversión.
  def eliminar_recursivo(stock)
    stock.derivados.find_each { |d| eliminar_recursivo(d) }
    stock.reservas.where(estado: 'pendiente').find_each(&:destroy!)
    stock.dispensaciones.no_canceladas.find_each { |d| revertir_y_destruir(d) }
    devolver_gramos_al_origen(stock)
    stock.reload.destroy! # stock_movimientos se borran en cascada
  end

  # Un derivado consumió gramos de un stock de origen. Al borrarlo, devolvemos los gramos Y
  # quitamos el movimiento de producción del historial del origen (no queda rastro huérfano).
  # Si el origen también está siendo borrado en esta cascada, es inocuo (se elimina después).
  def devolver_gramos_al_origen(stock)
    origen = stock.producido_desde_stock
    gramos = stock.lote_origen_consumido_g.to_d
    return unless origen && gramos > 0

    origen.update!(
      cantidad: origen.cantidad.to_d + gramos,
      estado:   origen.estado == 'agotado' ? 'asignado' : origen.estado,
    )
    origen.stock_movimientos.where(stock_resultante_id: stock.id).destroy_all
  end

  # Valida el stock y, recursivamente, todos sus derivados.
  def validar!
    arbol(@stock).each { |s| validar_stock!(s) }
  end

  def arbol(stock)
    [stock] + stock.derivados.flat_map { |d| arbol(d) }
  end

  def validar_stock!(stock)
    etiqueta = "'#{stock.forma_producto}'"
    if stock.dispensaciones.where(estado_envio: 'entregado').exists?
      raise Bloqueado, "No se puede borrar: #{etiqueta} tiene despachos ya entregados. Cancelalos primero."
    end
    if stock.dispensaciones.any? { |d| d.movimientos_contables.any?(&:cerrado?) }
      raise Bloqueado, "No se puede borrar: #{etiqueta} tiene dispensaciones en un período contable cerrado."
    end
    if stock.reservas.where(estado: 'pendiente').where('sena_ars > 0').exists?
      raise Bloqueado, "No se puede borrar: #{etiqueta} tiene reservas con seña cobrada. Resolvelas primero."
    end
  end

  def revertir_y_destruir(dispensacion)
    revertir_gramos(dispensacion)
    revertir_cuenta_corriente(dispensacion)
    CuentaCorrienteMovimiento.where(dispensacion_id: dispensacion.id).update_all(dispensacion_id: nil)
    dispensacion.movimientos_contables.destroy_all
    dispensacion.destroy  # after_destroy :incrementar_stock (inocuo: el stock se borra a continuación)
  end

  def revertir_gramos(dispensacion)
    cc = dispensacion.paciente.cuenta_corriente
    return unless cc
    total_g = cc.movimientos.where(dispensacion: dispensacion, tipo: 'debito')
                .where("unidad = 'gramos' OR descripcion ILIKE ?", '%(crédito gramos)%')
                .sum(:monto).abs
    return if total_g <= 0
    anterior = cc.saldo_disponible_g.to_d
    nuevo    = anterior + total_g
    cc.update!(saldo_disponible_g: nuevo)
    cc.movimientos.create!(
      tipo: 'ajuste', monto: total_g, saldo_anterior: anterior, saldo_nuevo: nuevo,
      descripcion: "Reversa dispensación ##{dispensacion.id} (gramos) — borrado de stock",
      created_by: @usuario,
    )
  end

  def revertir_cuenta_corriente(dispensacion)
    cc = dispensacion.paciente.cuenta_corriente
    return unless cc
    total = cc.movimientos.where(dispensacion: dispensacion, tipo: 'debito')
              .where("unidad IS NULL OR unidad = 'ars'")
              .sum(:monto).abs
    return if total <= 0
    anterior = cc.saldo_disponible
    nuevo    = anterior + total
    cc.update!(saldo_disponible: nuevo)
    cc.movimientos.create!(
      tipo: 'ajuste', monto: total, saldo_anterior: anterior, saldo_nuevo: nuevo,
      descripcion: "Reversa dispensación ##{dispensacion.id} — borrado de stock",
      created_by: @usuario,
    )
  end
end
