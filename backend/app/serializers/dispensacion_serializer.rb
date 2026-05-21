class DispensacionSerializer
  def self.serialize(d)
    {
      id:              d.id,
      club_id:         d.sede&.club_id,
      paciente_id:     d.paciente_id,
      paciente_nombre: "#{d.paciente.nombre} #{d.paciente.apellido}",
      usuario:         { id: d.user.id, nombre: d.user.first_name || d.user.email },
      sede:            d.sede ? { id: d.sede.id, nombre: d.sede.nombre } : nil,
      stock:           StockSerializer.serialize_dispensacion(d.stock),
      cantidad:            d.cantidad.to_f,
      precio_unitario_ars: d.precio_unitario_ars&.to_f,
      aporte_socio_ars:    d.aporte_socio_ars&.to_f,
      observaciones:       d.observaciones,
      fecha_dispensacion:  d.fecha_dispensacion,
      medio_pago:          d.medio_pago,
      tiene_movimiento_contable: d.movimiento_contable.present?,
      con_envio:       d.con_envio,
      estado_envio:    d.estado_envio,
      codigo_paquete:  d.codigo_paquete,
      delivery_id:     d.delivery_id,
      delivery_nombre: d.delivery_user ? [d.delivery_user.first_name, d.delivery_user.last_name].compact.join(' ').strip.presence || d.delivery_user.email : nil,
      direccion_envio:   d.direccion_envio,
      contacto_nombre:   d.contacto_nombre,
      contacto_telefono: d.contacto_telefono,
      notas_envio:       d.notas_envio,
      created_at:        d.created_at,
    }
  end

  def self.serialize_delivery(d)
    {
      id:                 d.id,
      codigo_paquete:     d.codigo_paquete,
      estado_envio:       d.estado_envio,
      entregado_at:       d.entregado_at,
      notas_entrega:      d.notas_entrega,
      motivo_fallo:       d.motivo_fallo,
      fecha_dispensacion: d.fecha_dispensacion,
      cantidad:           d.cantidad.to_f,
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
      stock: d.stock ? { forma_producto: d.stock.forma_producto, unidad: d.stock.unidad } : nil,
    }
  end
end
