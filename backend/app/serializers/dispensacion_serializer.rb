class DispensacionSerializer
  def self.serialize(d)
    {
      id:              d.id,
      token:           d.token,
      club_id:         d.sede&.club_id,
      paciente_id:     d.paciente_id,
      paciente_nombre: "#{d.paciente.nombre} #{d.paciente.apellido}",
      usuario:         { id: d.user.id, nombre: d.user.first_name || d.user.email },
      sede:            d.sede ? { id: d.sede.id, nombre: d.sede.nombre } : nil,
      stock:           StockSerializer.serialize_dispensacion(d.stock),
      items:           serialize_items(d),
      multi_stock:     d.multi_stock?,
      cantidad:            d.cantidad.to_f,
      precio_unitario_ars: d.precio_unitario_ars&.to_f,
      aporte_socio_ars:    d.aporte_socio_ars&.to_f,
      descuento_paciente_pct: d.descuento_paciente_pct&.to_f,
      descuento_dispensa_pct: d.descuento_dispensa_pct&.to_f,
      descuento_otorgado_por: (d.descuento_dispensa_pct.to_f > 0 && d.user) ? (d.user.first_name || d.user.email) : nil,
      lote_codigo:         d.lote_codigo     || d.stock&.lote&.codigo,
      genetica_nombre:     d.genetica_nombre || d.stock&.genetica&.nombre || d.stock&.lote&.genetica&.nombre,
      observaciones:       d.observaciones,
      fecha_dispensacion:  d.fecha_dispensacion,
      medio_pago:          d.medio_pago,
      tiene_movimiento_contable: d.movimientos_contables.any?,
      monto_credito_ars:   d.monto_credito_ars&.to_f,
      monto_efectivo_ars:  (d.aporte_socio_ars.to_d - d.monto_credito_ars.to_d).to_f,
      cobrar_en_entrega:   d.cobrar_en_entrega,
      total_cobrado:       d.total_cobrado.to_f,
      saldo_pendiente:     d.saldo_pendiente.to_f,
      cobros:              d.cobros.recientes.map { |c| CobroSerializer.serialize(c) },
      comprobante_entrega_url: (d.comprobante_entrega.attached? ? Rails.application.routes.url_helpers.rails_blob_path(d.comprobante_entrega, only_path: true) : nil),
      con_envio:       d.con_envio,
      estado_envio:    d.estado_envio,
      codigo_paquete:  d.codigo_paquete,
      delivery_id:     d.delivery_id,
      delivery_nombre: d.delivery_user ? [d.delivery_user.first_name, d.delivery_user.last_name].compact.join(' ').strip.presence || d.delivery_user.email : nil,
      direccion_envio:   d.direccion_envio,
      contacto_nombre:   d.contacto_nombre,
      contacto_telefono: d.contacto_telefono,
      notas_envio:        d.notas_envio,
      notas_entrega:      d.notas_entrega,
      firma_entrega_data: d.firma_entrega_data,
      entregado_at:       d.entregado_at,
      motivo_fallo:       d.motivo_fallo,
      historial_envio:    d.historial_envio || [],
      orden_entrega:      d.orden_entrega,
      ruta_id:            d.ruta_entrega_id,
      ruta_bloqueada:     d.ruta_entrega&.bloqueada || false,
      created_at:         d.created_at,
    }
  end

  def self.serialize_delivery(d)
    {
      id:                 d.id,
      codigo_paquete:     d.codigo_paquete,
      estado_envio:       d.estado_envio,
      orden_entrega:      d.orden_entrega,
      ruta_bloqueada:     d.ruta_entrega&.bloqueada || false,
      entregado_at:       d.entregado_at,
      notas_entrega:      d.notas_entrega,
      firma_entrega_data: d.firma_entrega_data,
      motivo_fallo:       d.motivo_fallo,
      historial_envio:    d.historial_envio || [],
      fecha_dispensacion: d.fecha_dispensacion,
      # Privacidad del delivery: NO se expone qué ni cuánto lleva (cantidad/stock/items).
      # Solo lo necesario para entregar y cobrar contra-entrega (monto, saldo, contacto).
      aporte_socio_ars:   d.aporte_socio_ars&.to_f,
      cobrar_en_entrega:  d.cobrar_en_entrega,
      saldo_pendiente:    d.saldo_pendiente.to_f,
      total_cobrado:      d.total_cobrado.to_f,
      cobros:             d.cobros.recientes.map { |c| CobroSerializer.serialize(c) },
      comprobante_entrega_url: (d.comprobante_entrega.attached? ? Rails.application.routes.url_helpers.rails_blob_path(d.comprobante_entrega, only_path: true) : nil),
      observaciones:      d.observaciones,
      direccion_envio:    d.direccion_envio,
      contacto_nombre:    d.contacto_nombre,
      contacto_telefono:  d.contacto_telefono,
      notas_envio:        d.notas_envio,
      paciente: {
        id:       d.paciente.id,
        nombre:   "#{d.paciente.nombre} #{d.paciente.apellido}",
        telefono: d.paciente.telefono,
      },
      sede:  d.sede ? { id: d.sede.id, nombre: d.sede.nombre } : nil,
    }
  end

  # Líneas de la dispensación (multi-stock). Cada una con su stock, cantidad, precio y trazabilidad.
  def self.serialize_items(d)
    # Legacy: dispensas previas al refactor multi-stock no tienen filas DispensacionItem.
    # Se sintetiza un ítem único desde el stock+cantidad de la dispensa, así el front trata
    # a todas por igual (siempre hay al menos un ítem).
    if d.items.empty?
      return [] unless d.stock
      subtotal = d.precio_unitario_ars&.to_f ? (d.precio_unitario_ars.to_f * d.cantidad.to_f).round(2) : d.aporte_socio_ars.to_f
      return [{
        id:                  nil,
        stock_id:            d.stock_id,
        stock:               StockSerializer.serialize_dispensacion(d.stock),
        cantidad:            d.cantidad.to_f,
        precio_unitario_ars: d.precio_unitario_ars&.to_f,
        subtotal_ars:        subtotal,
        lote_codigo:         d.lote_codigo     || d.stock&.lote&.codigo,
        genetica_nombre:     d.genetica_nombre || d.stock&.genetica&.nombre || d.stock&.lote&.genetica&.nombre,
      }]
    end

    d.items.map do |it|
      {
        id:                  it.id,
        stock_id:            it.stock_id,
        stock:               StockSerializer.serialize_dispensacion(it.stock),
        cantidad:            it.cantidad.to_f,
        precio_unitario_ars: it.precio_unitario_ars&.to_f,
        subtotal_ars:        it.subtotal_ars.to_f,
        lote_codigo:         it.lote_codigo,
        genetica_nombre:     it.genetica_nombre,
      }
    end
  end
end
