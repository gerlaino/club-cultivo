# Deriva los costos del lote desde el libro contable (egresos con lote_id),
# eliminando la doble carga manual que hacía divergir CostoLote del libro.
# El libro es la fuente de verdad para insumos, energía y mano de obra;
# costo_prorrateado, gramos_producidos y notas siguen siendo manuales.
#
# Se invoca automáticamente cuando cambia un movimiento contable con lote
# (after_commit en MovimientoContable) y manualmente vía
# POST /lotes/:lote_id/costo/recalcular.
class CostoDesdeLibroService
  MAPEO_CATEGORIAS = {
    costo_insumos:   %w[insumo],
    costo_energia:   %w[electricidad agua],
    costo_mano_obra: %w[sueldo honorario mantenimiento],
  }.freeze

  # Lo que NO es un gasto del lote aunque llegue con `lote_id`: movimientos de caja e ingresos
  # mal tipificados. Todo lo demás que no cae en los tres cajones de arriba —alquiler, seguro,
  # administrativo, `otro`, los tipos que crea el usuario— va a `costo_otros`: antes no iba a
  # ningún lado y el costo por gramo salía sin la lámpara ni la carpa.
  CATEGORIAS_NO_COSTO = %w[
    aporte_socio dispensacion subvencion bar
    salida_caja retiro_caja devolucion_caja diferencia_caja ingreso_caja
    a_cuenta_repartidor devolucion_a_cuenta devolucion_paciente
  ].freeze

  def initialize(lote:, actualizado_por: nil)
    @lote            = lote
    @actualizado_por = actualizado_por
  end

  def call
    egresos = MovimientoContable.egresos.where(lote_id: @lote.id)

    costo = @lote.costo_lote || @lote.build_costo_lote(club: @lote.club)

    MAPEO_CATEGORIAS.each do |campo, categorias|
      costo[campo] = egresos.where(categoria: categorias).sum(:monto_ars)
    end
    mapeadas = MAPEO_CATEGORIAS.values.flatten
    costo.costo_otros = egresos.where.not(categoria: mapeadas + CATEGORIAS_NO_COSTO).sum(:monto_ars)

    # Costo real de insumos consumidos del depósito e imputados a este lote (Bloque 2).
    # Se suma a los egresos de insumo cargados directo con lote (ambas fuentes conviven).
    consumos = InsumoConsumo.where(club_id: @lote.club_id, lote_id: @lote.id).sum(:costo_imputado_ars)
    costo.costo_insumos = costo.costo_insumos.to_d + consumos

    # (Los desprendimientos —lo heredado y lo cedido— los suma `CostoLote#calcular_costo_total`, para
    # no pisar `costo_prorrateado`, que es del usuario.)

    # Si el lote ya tiene rendimiento real y nadie cargó gramos, usarlo
    if costo.gramos_producidos.blank? && @lote.rendimiento_real_g.to_d > 0
      costo.gramos_producidos = @lote.rendimiento_real_g
    end

    costo.calculado_at  = Time.current
    costo.calculado_por = @actualizado_por if @actualizado_por
    costo.save!
    costo
  end
end
