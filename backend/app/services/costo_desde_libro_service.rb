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
