class StockSerializer
  def self.serialize_inline(s)
    {
      id:                  s.id,
      origen:              s.origen,
      forma_producto:      s.forma_producto,
      unidad:              s.unidad,
      cantidad:            s.cantidad.to_f,
      estado:              s.estado,
      sede_id:             s.sede_id,
      precio_sugerido_ars: s.precio_sugerido_ars&.to_f,
      lote_codigo:         s.lote&.codigo,
    }
  end

  def self.serialize_dispensacion(stk)
    return nil unless stk
    {
      id:                  stk.id,
      forma_producto:      stk.forma_producto,
      unidad:              stk.unidad,
      precio_sugerido_ars: stk.precio_sugerido_ars&.to_f,
      regulatorio:         stk.regulatorio?,
      lote:                stk.lote ? { id: stk.lote.id, codigo: stk.lote.codigo } : nil,
    }
  end
end
