module Portal
  # El estado del paciente: su credencial y lo que hay que decirle antes de que scrollee.
  #
  # Alimenta dos cosas que se ven distinto pero salen del mismo dato:
  #
  #   `credencial` — la tarjeta del inicio, y lo que muestra en la puerta. Es la pantalla más
  #                  abierta de cualquier portal de este tipo, y la única que se usa PARADO.
  #   `avisos`     — la franja de arriba, que sólo se dibuja si hay algo urgente.
  #
  # El aviso más valioso —y el único que el portal da y ninguna otra pantalla— es que se le vence
  # el REPROCANN ANTES de que se le venza. Vencido, no puede retirar.
  class MiEstadoController < BaseController
    # Cuántos días antes se empieza a avisar. Un mes es el tiempo real que lleva el trámite de
    # renovación: avisar con una semana es avisar tarde.
    DIAS_AVISO_REPROCANN = 30

    def show
      return render json: { data: { credencial: nil, avisos: [] } } if ficha.nil?

      render json: {
        data: {
          nombre:       ficha.nombre,
          carnet_token: ficha.carnet_token,
          credencial:   credencial,
          avisos:       [aviso_reprocann, aviso_saldo].compact,
        },
      }
    end

    private

    def ficha
      @ficha ||= current_club.pacientes.find_by(user_id: current_user.id)
    end

    # Su propia credencial, con su propio DNI y su propio número: esto va detrás de SU login, así
    # que no se anonimiza nada. Es al revés que `/c/:token`, que es un link que la persona entrega
    # y por eso muestra la inicial del apellido y ningún documento.
    def credencial
      {
        nombre:                ficha.nombre,
        apellido:              ficha.apellido,
        dni:                   ficha.dni,
        numero_socio:          ficha.id,
        miembro_desde:         ficha.created_at.to_date,
        carnet_token:          ficha.carnet_token,
        reprocann_numero:      ficha.reprocann_numero,
        reprocann_vencimiento: ficha.reprocann_vencimiento,
        # La MISMA categoría que usa el informe REPROCANN. Que la tarjeta del paciente y el
        # informe del auditor digan lo mismo no es un detalle: son la misma pregunta.
        reprocann_categoria:   Paciente.reprocann_categoria(
          estado:      ficha.reprocann_estado_efectivo,
          numero:      ficha.reprocann_numero,
          vencimiento: ficha.reprocann_vencimiento,
        ),
        dias_para_vencer:      dias_para_vencer,
        habilitado:            ficha.reprocann_estado_efectivo.to_s == 'activo',
      }
    end

    def dias_para_vencer
      return nil if ficha.reprocann_vencimiento.blank?

      (ficha.reprocann_vencimiento - Time.zone.today).to_i
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
