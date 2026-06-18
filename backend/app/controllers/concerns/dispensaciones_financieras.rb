# Helpers financieros compartidos entre la creación de dispensaciones y la entrega de
# reservas. Se extrajeron de DispensacionesController sin cambiar su comportamiento, para
# que la entrega de una reserva (que también crea una Dispensacion real) registre el
# movimiento contable y debite la cuenta corriente con EXACTAMENTE la misma lógica.
#
# Dependen de `current_user` (controller), por eso viven como concern de controller.
module DispensacionesFinancieras
  extend ActiveSupport::Concern

  private

  def crear_movimiento_contable(dispensacion)
    total = dispensacion.aporte_socio_ars.to_d
    return if total <= 0

    base_desc = "Dispensación #{dispensacion.cantidad}#{dispensacion.stock&.unidad} " \
      "#{dispensacion.stock&.forma_producto} — " \
      "#{dispensacion.paciente.nombre} #{dispensacion.paciente.apellido}"

    if dispensacion.a_credito?
      credito  = dispensacion.monto_credito_ars.to_d
      efectivo = total - credito
      # Parte a crédito: deuda visible (no entra plata, pagado: false).
      asiento_contable(dispensacion, credito,  "#{base_desc} (crédito)",  pagado: false, medio: dispensacion.medio_pago) if credito > 0
      # Diferencia cobrada ahora: ingreso real en efectivo.
      asiento_contable(dispensacion, efectivo, "#{base_desc} (efectivo)", pagado: true,  medio: 'efectivo')             if efectivo > 0
    else
      asiento_contable(dispensacion, total, base_desc, pagado: true, medio: dispensacion.medio_pago || 'efectivo')
    end
  end

  def asiento_contable(dispensacion, monto, descripcion, pagado:, medio:)
    return if monto.to_d <= 0
    MovimientoContable.create!(
      club:             current_user.club,
      sede_id:          dispensacion.sede_id,
      dispensacion:     dispensacion,
      created_by:       current_user,
      tipo:             'recupero_costo',
      categoria:        'dispensacion',
      descripcion:      descripcion,
      monto_ars:        monto,
      fecha:            dispensacion.fecha_dispensacion,
      pagado:           pagado,
      medio_pago:       medio || 'efectivo',
      comprobante_tipo: 'sin_comprobante',
    )
  end

  def debitar_cuenta_corriente(dispensacion)
    # Solo se debita al crédito la parte que cae sobre la cuenta corriente.
    monto = dispensacion.monto_credito_ars.to_d
    return if monto <= 0

    cc = dispensacion.paciente.cuenta_corriente
    # Guard: evitar doble débito si la dispensación ya tiene un movimiento registrado
    return if cc.movimientos.exists?(dispensacion: dispensacion, tipo: 'debito')

    anterior = cc.saldo_disponible
    nuevo    = anterior - monto
    cc.update!(saldo_disponible: nuevo)
    cc.movimientos.create!(
      tipo:           'debito',
      unidad:         'ars',
      monto:          -monto,
      saldo_anterior: anterior,
      saldo_nuevo:    nuevo,
      descripcion:    "Dispensación: #{dispensacion.cantidad}#{dispensacion.stock&.unidad} #{dispensacion.stock&.forma_producto}",
      dispensacion:   dispensacion,
      created_by:     current_user,
    )
  end

  def debitar_gramos(dispensacion)
    gramos = dispensacion.cantidad.to_d
    return if gramos <= 0

    cc = dispensacion.paciente.cuenta_corriente
    return unless cc&.credito_gramos_activo?
    return if cc.movimientos.exists?(dispensacion: dispensacion, tipo: 'debito')

    anterior = cc.saldo_disponible_g.to_d
    nuevo    = anterior - gramos
    cc.update!(saldo_disponible_g: nuevo)
    cc.movimientos.create!(
      tipo:           'debito',
      unidad:         'gramos',
      monto:          -gramos,
      saldo_anterior: anterior,
      saldo_nuevo:    nuevo,
      descripcion:    "Dispensación #{gramos}g (crédito gramos)",
      dispensacion:   dispensacion,
      created_by:     current_user,
    )
  end
end
