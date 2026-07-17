# Helpers financieros compartidos entre la creación de dispensaciones y la entrega de
# reservas. Se extrajeron de DispensacionesController sin cambiar su comportamiento, para
# que la entrega de una reserva (que también crea una Dispensacion real) registre el
# movimiento contable y debite la cuenta corriente con EXACTAMENTE la misma lógica.
#
# Dependen de `current_user` (controller), por eso viven como concern de controller.
module DispensacionesFinancieras
  extend ActiveSupport::Concern

  private

  # ── Flujo de cobros (compartido entre dispensar y entregar reserva) ─────────

  # Líneas de cobro que manda el front: [{ medio, monto }]. Acepta el array bajo
  # :dispensacion (create) o al tope (entrega). En multipart (cuando hay foto) llegan
  # como hash {"0" => {...}}, así que normalizamos a lista. Filtra montos <= 0.
  def cobros_param
    raw = params.dig(:dispensacion, :cobros) || params[:cobros]
    return [] if raw.blank?
    entries = raw.respond_to?(:values) ? raw.values : raw   # hash multipart → lista
    entries.map { |c| { medio: c[:medio].to_s, monto: c[:monto].to_d } }.reject { |c| c[:monto] <= 0 }
  end

  def comprobante_param
    params[:comprobante] || params.dig(:dispensacion, :comprobante)
  end

  # Registra los cobros de una dispensa. Cada línea cubre hasta el saldo; lo que pague
  # de más (transfirió de más, le pagó de más al delivery, etc.) NO se bloquea: el
  # excedente se acredita a favor en su cuenta corriente. Lo que falte cubrir queda como
  # deuda en cuenta corriente. La foto se adjunta al primer cobro de transferencia.
  def aplicar_lineas_cobro!(disp, lineas, contexto)
    comp = comprobante_param
    comp_usado = false
    excedente  = 0.to_d

    lineas.each do |l|
      saldo = disp.monto_sin_cobrar
      monto = l[:monto].to_d
      cobro = [monto, saldo].min          # lo que entra contra esta dispensa
      excedente += (monto - cobro)        # lo que sobra → a favor

      next if cobro <= 0
      usar = !comp_usado && comp.present?  # comprobante de pago → al primer cobro
      comp_usado ||= usar
      res = Dispensaciones::RegistrarCobro.call(
        dispensacion: disp, club: current_user.club, usuario: current_user,
        medio: l[:medio], monto: cobro, contexto: contexto,
        comprobante: (usar ? comp : nil))
      raise res.error unless res.ok?
    end

    # Lo que falta cubrir → deuda en cuenta corriente.
    saldo = disp.monto_sin_cobrar
    if saldo > 0.001
      res = Dispensaciones::RegistrarCobro.call(
        dispensacion: disp, club: current_user.club, usuario: current_user,
        medio: 'cuenta_corriente', monto: saldo, contexto: contexto)
      raise res.error unless res.ok?
    end

    acreditar_excedente!(disp, excedente.round(2)) if excedente > 0.001
  end

  # Excedente pagado por el socio → crédito a favor en su cuenta corriente.
  # NO es ingreso del club: es plata del socio parkeada como crédito (un pasivo). Por eso
  # se acredita DIRECTO en la CC, sin asiento contable 'aporte_socio' (que lo contaba como
  # ingreso e inflaba el libro). Cuando el socio use ese crédito en una dispensa futura, esa
  # dispensa se cobra contra la CC. Requiere que tenga cuenta corriente.
  def acreditar_excedente!(disp, monto)
    cc = disp.paciente.cuenta_corriente
    unless cc
      raise "El socio no tiene cuenta corriente para acreditar el excedente ($#{monto.to_f}). Ajustá el monto cobrado."
    end
    anterior = cc.saldo_disponible
    nuevo    = anterior + monto.to_d
    ActiveRecord::Base.transaction do
      cc.update!(saldo_disponible: nuevo)
      cc.movimientos.create!(
        tipo:           'pago',
        unidad:         'ars',
        monto:          monto.to_d,
        saldo_anterior: anterior,
        saldo_nuevo:    nuevo,
        descripcion:    "Excedente de pago — Dispensación ##{disp.id}",
        dispensacion:   disp,
        created_by:     current_user,
      )
    end
  end

  # medio_pago denormalizado de la dispensa: el único medio, o 'mixto' si hay varios.
  # También sincroniza monto_credito_ars (lo que quedó a cuenta) para los serializers.
  def afinar_medio_pago!(disp)
    medios = disp.cobros.pluck(:medio).uniq
    disp.update_columns(
      medio_pago:        medios.size == 1 ? medios.first : 'mixto',
      monto_credito_ars: disp.cobros.a_credito.sum(:monto_ars),
    )
  end

  # Estos tres efectos viven en Dispensaciones::AplicarEfectos (fuente única, compartida con la
  # restauración). Acá se delega pasando current_user como actor.
  def crear_movimiento_contable(dispensacion)
    Dispensaciones::AplicarEfectos.new(dispensacion, current_user).crear_movimiento_contable
  end

  def debitar_cuenta_corriente(dispensacion)
    Dispensaciones::AplicarEfectos.new(dispensacion, current_user).debitar_cuenta_corriente
  end

  def debitar_gramos(dispensacion)
    Dispensaciones::AplicarEfectos.new(dispensacion, current_user).debitar_gramos
  end
end
