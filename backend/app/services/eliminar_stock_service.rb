# Borra un stock Y EN CASCADA sus derivados (los productos elaborados a partir de él). Eliminar
# es para el error de carga: un stock que nunca debió existir. Por eso NO se puede eliminar un stock
# que ya se dispensó (16-oct-2026, Germán: «si se hicieron dispensas no se debería poder eliminar el
# stock, sólo dar de baja/finalizar»), ni él ni ninguno de sus derivados, aunque la dispensa esté
# anulada: es historia de un paciente y el informe la cuenta. Ese stock se finaliza.
# También bloquea si hay reservas con seña cobrada. Las reservas sin seña se borran con él.
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

  # Por qué no se puede eliminar (o nil). La ficha lo usa para apagar el botón y decirlo.
  def motivo_bloqueo
    validar!
    nil
  rescue Bloqueado => e
    e.message
  end

  private

  # Borra un stock y, primero, sus derivados (en profundidad), con la misma reversión.
  def eliminar_recursivo(stock)
    stock.derivados.find_each { |d| eliminar_recursivo(d) }
    # Soft-borrar TODO lo que referencia al stock con FK NOT NULL antes de destruirlo: si quedara
    # algo, el dependent: :nullify intentaría poner stock_id = NULL y violaría la constraint.
    # (Dispensas no hay: bloquearon en validar!, igual que las reservas con seña).
    stock.reservas_que_lo_incluyen.find_each(&:destroy!)
    devolver_gramos_al_origen(stock)
    # Quién lo borró: el historial lo muestra (15-oct-2026). No se guardaba y un stock eliminado
    # quedaba sin rastro de quién ni por qué.
    stock.update_column(:deleted_by_id, @usuario&.id)
    stock.reload.destroy! # stock_movimientos se borran en cascada
  end

  # Un derivado consumió gramos de un stock de origen. Al borrarlo, los gramos vuelven al origen
  # y la producción SE QUITA del historial del origen: eliminar es deshacer un error de carga, como
  # si nunca hubiera pasado (16-oct-2026, Germán: «eliminar stock producido no debería reflejarse
  # en el historial ya que sería un error humano»). Saldo e historial quedan como antes de producir.
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
    etiqueta = stock.numero_lote_producto.presence || "'#{stock.forma_producto}'"
    propio   = stock.id == @stock.id ? 'este stock' : "su derivado #{etiqueta}"
    if dispensas_de(stock).exists?
      raise Bloqueado, "No se puede eliminar: #{propio} ya tiene dispensas. Eliminar es para un error de carga; un stock que se entregó se finaliza («Finalizar stock»)."
    end
    if stock.reservas_que_lo_incluyen.where(estado: 'pendiente').where('sena_ars > 0').exists?
      raise Bloqueado, "No se puede eliminar: #{propio} tiene reservas con seña cobrada. Resolvelas primero."
    end
  end

  # Toda dispensa que lo tocó, anulada o no: por la columna espejo (la primera línea) o por
  # cualquiera de sus líneas (una dispensa de varios productos sólo espeja el primero).
  def dispensas_de(stock)
    Dispensacion.where(stock_id: stock.id)
                .or(Dispensacion.where(id: DispensacionItem.where(stock_id: stock.id).select(:dispensacion_id)))
  end
end
