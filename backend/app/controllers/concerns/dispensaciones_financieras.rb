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
    monto = dispensacion.aporte_socio_ars.to_d
    return if monto <= 0

    descripcion = "Dispensación #{dispensacion.cantidad}#{dispensacion.stock&.unidad} " \
      "#{dispensacion.stock&.forma_producto} — " \
      "#{dispensacion.paciente.nombre} #{dispensacion.paciente.apellido}"

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
      # Contabilidad de caja: a crédito no entra plata real, queda como deuda visible.
      # El ingreso real se registra cuando el socio paga (aporte_socio).
      pagado:           !dispensacion.a_credito?,
      medio_pago:       dispensacion.medio_pago || 'efectivo',
      comprobante_tipo: 'sin_comprobante',
    )
  end

  def debitar_cuenta_corriente(dispensacion)
    monto = dispensacion.aporte_socio_ars.to_d
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
