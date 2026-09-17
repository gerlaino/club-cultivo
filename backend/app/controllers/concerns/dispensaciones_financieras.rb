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

  # A qué caja va la plata cuando administración dispensa del depósito. Sólo administración lo
  # elige: quien atiende cobra en la suya (`Dispensacion#caja_para_cobros`).
  def caja_elegida_param
    return nil if current_user.atiende_mostrador?

    params.dig(:dispensacion, :caja_turno_id).presence || params[:caja_turno_id].presence
  end

  # Registra los cobros de una dispensa. Cada línea cubre hasta el saldo; lo que pague
  # de más (transfirió de más, le pagó de más al delivery, etc.) NO se bloquea: el
  # excedente se acredita a favor en su cuenta corriente. Lo que falte cubrir queda como
  # deuda en cuenta corriente. La foto se adjunta al primer cobro de transferencia.
  #
  # `dejar_saldo`: lo que falte NO va a cuenta corriente, queda PENDIENTE para que lo cobre el
  # repartidor en la puerta (decisión de Germán, sep-2026: una parte se paga ahora, por
  # transferencia o efectivo, y el resto contra entrega). Lo que ya entró se asienta ya; el
  # repartidor ve `saldo_pendiente`, que es lo único que necesita.
  def aplicar_lineas_cobro!(disp, lineas, contexto, dejar_saldo: false)
    disp.caja_turno_elegida_id = caja_elegida_param if caja_elegida_param.present?
    comp = comprobante_param
    comp_usado = false
    excedente  = 0.to_d

    medio_excedente = nil
    # Lo que debía ANTES de esta dispensa: es hasta donde se puede pagar de más.
    deuda_previa = [-(disp.paciente.cuenta_corriente&.saldo_disponible || 0).to_d, 0].max

    lineas.each do |l|
      saldo = disp.monto_sin_cobrar
      monto = l[:monto].to_d
      cobro = [monto, saldo].min          # lo que entra contra esta dispensa
      sobra = monto - cobro               # lo que sobra → a favor
      # La cuenta corriente cubre lo que FALTA; no puede sobrar por ahí. «Efectivo 30.000 +
      # cuenta corriente 10.000» sobre un total de 30.000 no significa nada (pasó en producción:
      # el paciente había pagado 40.000 en efectivo y la segunda línea se cargó mal), y dejarlo
      # pasar acreditaba 10.000 que nadie puso.
      if sobra > 0.001 && l[:medio].to_s == 'cuenta_corriente'
        raise "La cuenta corriente sólo cubre lo que falta (#{pesos(saldo)}). Si pagó de más, cargalo en el medio con el que pagó."
      end
      excedente += sobra
      medio_excedente ||= l[:medio] if sobra > 0.001

      next if cobro <= 0
      usar = !comp_usado && comp.present?  # comprobante de pago → al primer cobro
      comp_usado ||= usar
      res = Dispensaciones::RegistrarCobro.call(
        dispensacion: disp, club: current_user.club, usuario: current_user,
        medio: l[:medio], monto: cobro, contexto: contexto,
        comprobante: (usar ? comp : nil))
      raise res.error unless res.ok?
    end

    # Lo que falta cubrir → deuda en cuenta corriente (salvo que lo cobre el repartidor).
    saldo = disp.monto_sin_cobrar
    if saldo > 0.001 && !dejar_saldo
      res = Dispensaciones::RegistrarCobro.call(
        dispensacion: disp, club: current_user.club, usuario: current_user,
        medio: 'cuenta_corriente', monto: saldo, contexto: contexto)
      raise res.error unless res.ok?
    end

    # SE PUEDE PAGAR DE MÁS SÓLO PARA BAJAR DEUDA (decisión de Germán, 16-sep-2026), y NO HAY PLATA
    # A FAVOR (17-sep): la cuenta corriente es lo que el paciente debe, y nada más. Dejar plata «a
    # favor» al cobrar era que el club se quedara con plata del paciente por accidente —un número
    # mal tipeado se volvía un crédito que después alguien tenía que explicar—.
    if excedente > deuda_previa + 0.001
      raise(if deuda_previa.positive?
              "Paga #{pesos(excedente)} de más y sólo debe #{pesos(deuda_previa)}: cobrale hasta #{pesos(deuda_previa)} de más. " \
              'Si trajo de más, dale el vuelto: no hay saldo a favor.'
            else
              "Paga #{pesos(excedente)} de más y no debe nada: cobrale el total exacto. " \
              'Si trajo de más, dale el vuelto: no hay saldo a favor.'
            end)
    end
    acreditar_excedente!(disp, excedente.round(2), medio: medio_excedente) if excedente > 0.001
  end

  def pesos(n) = ActiveSupport::NumberHelper.number_to_currency(n, unit: '$', precision: 0, delimiter: '.', separator: ',')

  # Lo que el paciente pagó DE MÁS —hasta lo que debía— baja su deuda en la cuenta corriente, y
  # ENTRA al libro y a la caja como «Aporte socio», el mismo asiento que hace «Registrar pago».
  #
  # Hasta sep-2026 se acreditaba directo en la CC sin asiento, con el argumento de que es plata
  # del paciente y no ingreso. Lo que pasó en producción: pagó 40.000 en efectivo por una
  # dispensa de 30.000, el libro mostraba 30.000 y la caja cerraba con 10.000 de sobrante que
  # nadie podía explicar. La plata ENTRÓ, y el criterio que ya tenía la app para un pago que
  # deja saldo a favor («Registrar pago») es asentarlo como aporte. Un mismo hecho —el paciente
  # adelantó plata— no puede verse distinto según la puerta por la que entró.
  # (Germán, 16-sep: «pagaron 40 mil en total» y los 10 no aparecían.)
  #
  # El asiento va atado a la dispensa (`dispensacion_id`): al cancelarla o editarla se destruye
  # con los demás y `before_destroy` devuelve el crédito, como antes. El `after_create` del
  # movimiento es el que acredita la CC: acá no se toca el saldo a mano.
  def acreditar_excedente!(disp, monto, medio: nil)
    cc = disp.paciente.cuenta_corriente
    unless cc
      raise "El socio no tiene cuenta corriente para acreditar el excedente ($#{monto.to_f}). Ajustá el monto cobrado."
    end
    medio = MovimientoContable::MEDIOS_PAGO.include?(medio.to_s) ? medio.to_s : 'efectivo'
    caja  = medio == 'efectivo' ? disp.caja_para_cobros : nil
    MovimientoContable.create!(
      club:          current_user.club,
      sede_id:       disp.sede_id || current_user.club.sedes.activas.first&.id,
      paciente:      disp.paciente,
      dispensacion:  disp,
      created_by:    current_user,
      tipo:          'ingreso',
      categoria:     'aporte_socio',
      descripcion:   "Pagó de más — Dispensación ##{disp.id} (#{disp.paciente.nombre_completo}), baja su deuda",
      monto_ars:     monto.to_d,
      fecha:         disp.fecha_dispensacion || Date.current,
      pagado:        true,
      medio_pago:    medio,
      caja_turno_id: caja&.id,
    )
  end

  # medio_pago denormalizado de la dispensa: el único medio, o 'mixto' si hay varios.
  # También sincroniza monto_credito_ars (lo que quedó a cuenta) para los serializers.
  def afinar_medio_pago!(disp)
    medios = disp.cobros.pluck(:medio).uniq

    # SIN COBROS no hay nada que afinar, y "mixto" es una mentira: mixto significa que se pagó
    # de dos formas distintas, no que no se pagó. Pasaba al entregar una reserva cuyo resto era
    # cero (la seña ya cubría todo) o que se cobra contra entrega: la dispensación quedaba
    # marcada "mixto" sin un solo cobro detrás. Se conserva el medio con el que nació.
    if medios.empty?
      disp.update_columns(monto_credito_ars: 0)
      return
    end

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
