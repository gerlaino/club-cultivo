module Portal
  # Lo que hay que decirle al paciente ANTES de que scrollee.
  #
  # Alimenta la franja fija de arriba, que sólo aparece cuando hay algo que decir. Una franja que
  # dice algo siempre se deja de leer a la semana: si no hay nada, `avisos` viene vacío y la franja
  # no se dibuja.
  #
  # El aviso más valioso —y el único que el portal da y ninguna otra pantalla— es que se le vence el
  # REPROCANN ANTES de que se le venza. Vencido, no puede retirar.
  class MiEstadoController < BaseController
    # Cuántos días antes se empieza a avisar. Un mes es el tiempo real que lleva el trámite de
    # renovación: avisar con una semana es avisar tarde.
    DIAS_AVISO_REPROCANN = 30

    def show
      return render json: { data: { avisos: [] } } if ficha.nil?

      render json: {
        data: {
          nombre:        ficha.nombre,
          carnet_token:  ficha.carnet_token,
          avisos:        [aviso_reprocann, aviso_saldo].compact,
        },
      }
    end

    private

    def ficha
      @ficha ||= current_club.pacientes.find_by(user_id: current_user.id)
    end

    # Tres momentos y nada más: vencido, por vencer, y sin trámite iniciado. Vigente y lejos no es
    # un aviso — es el estado normal, y decirlo todos los días entrena a ignorar la franja.
    def aviso_reprocann
      estado = ficha.reprocann_estado_efectivo.to_s
      vence  = ficha.reprocann_vencimiento

      if estado == 'vencido'
        return { tipo: 'reprocann_vencido', nivel: 'urgente',
                 texto: 'Tu REPROCANN está vencido. Hasta que lo renueves no podés retirar.' }
      end

      if estado == 'activo' && vence.present?
        dias = (vence - Time.zone.today).to_i
        if dias <= DIAS_AVISO_REPROCANN
          return { tipo: 'reprocann_por_vencer', nivel: 'atencion', dias: dias,
                   texto: dias.zero? ? 'Tu REPROCANN vence hoy.' : "Tu REPROCANN vence en #{dias} #{'día'.pluralize(dias)}." }
        end
      end

      return { tipo: 'reprocann_sin_registro', nivel: 'atencion',
               texto: 'Todavía no tenés el REPROCANN cargado. Hablá con tu organización.' } if estado == 'sin_registro'

      nil
    end

    # Sólo si DEBE. Tener saldo a favor no es algo que haya que avisar arriba de todo.
    def aviso_saldo
      cc = ficha.cuenta_corriente
      return nil if cc.nil?

      debe = [-cc.saldo_disponible.to_f, 0].max
      return nil if debe <= 0

      { tipo: 'saldo_pendiente', nivel: 'atencion', monto: debe,
        texto: "Tenés #{ActionController::Base.helpers.number_to_currency(debe, unit: '$', separator: ',', delimiter: '.', precision: 0)} pendientes en tu cuenta." }
    end
  end
end
