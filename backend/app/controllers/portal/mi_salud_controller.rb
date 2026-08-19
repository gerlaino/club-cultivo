module Portal
  # Lo clínico del paciente, visto por el paciente: cuándo es su turno y qué le indicaron.
  #
  # Es lo que separa "el catálogo de mi club" de un portal de salud, y es lo que el paciente entra
  # a buscar cuando no entra a mirar novedades. El módulo médico existe desde hace meses y hasta
  # hoy el portal no lo leía: el paciente tenía que llamar para saber cuándo era su turno.
  #
  # ── Sobre los datos ────────────────────────────────────────────────────────────────────────
  #
  # `IndicacionMedica` tiene cuatro campos ENCRIPTADOS at-rest (Ley 25.326 art. 9): patología,
  # dosificación, vía y observaciones. Se sirven acá y está bien: son SUYOS, y el que pregunta es
  # él, autenticado, sobre su propia ficha. Lo que no se sirve nunca es lo que escribió el médico
  # PARA EL MÉDICO — `Turno#notas_post` son las notas posteriores a la consulta y no salen de acá
  # bajo ninguna forma. Por eso esto se arma con lista blanca campo por campo y no con un
  # `as_json`: un campo nuevo en la tabla no se filtra solo al portal.
  class MiSaludController < BaseController
    # Cuántos turnos futuros se muestran. El que importa es el próximo; los otros dos son para
    # que no parezca que no hay nada más.
    PROXIMOS = 3

    def show
      return render json: { data: vacio } if ficha.nil? || !current_club.feature?(:medico)

      turnos = ficha.turnos.proximos.where.not(estado: 'cancelado').limit(PROXIMOS).to_a

      render json: {
        data: {
          tiene_modulo:  true,
          proximo_turno: turnos.first && serializar_turno(turnos.first),
          turnos:        turnos.map { |t| serializar_turno(t) },
          indicacion:    indicacion_vigente && serializar_indicacion(indicacion_vigente),
        },
      }
    end

    private

    def vacio = { tiene_modulo: false, proximo_turno: nil, turnos: [], indicacion: nil }

    def ficha
      @ficha ||= current_club.pacientes.find_by(user_id: current_user.id)
    end

    # La más reciente de las activas. Una indicación vencida no se muestra como vigente, pero sí se
    # muestra: que diga "venció el 3 de agosto" es justamente el aviso de que hay que renovarla.
    def indicacion_vigente
      return @indicacion if defined?(@indicacion)

      @indicacion = ficha.indicacion_medicas.activas.order(fecha_emision: :desc).first
    end

    TIPOS = {
      'primera_vez'  => 'Primera consulta',
      'seguimiento'  => 'Seguimiento',
      'revision'     => 'Revisión',
      'urgencia'     => 'Urgencia',
    }.freeze

    def serializar_turno(t)
      {
        id:            t.id,
        fecha_hora:    t.fecha_hora,
        duracion_minutos: t.duracion_minutos,
        tipo:          t.tipo,
        tipo_label:    TIPOS.fetch(t.tipo, t.tipo.to_s.humanize),
        estado:        t.estado,
        motivo:        t.motivo,
        medico:        nombre_de(t.medico),
        # `notas_post` NO va. Son las notas que el médico escribe después de la consulta, para él.
      }
    end

    def serializar_indicacion(i)
      {
        id:                  i.id,
        patologia:           i.patologia,
        dosificacion:        i.dosificacion,
        via_administracion:  i.via_administracion,
        observaciones:       i.observaciones,
        fecha_emision:       i.fecha_emision,
        fecha_vencimiento:   i.fecha_vencimiento,
        dias_hasta_vencimiento: i.dias_hasta_vencimiento,
        vencida:             i.vencida?,
        por_vencer:          i.por_vencer?,
        medico:              nombre_de(i.user),
      }
    end

    def nombre_de(user)
      return nil if user.nil?

      user.nombre_completo.presence || user.email
    end
  end
end
