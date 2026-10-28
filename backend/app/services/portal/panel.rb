# La pantalla del portal del lado del admin (Germán, 28-oct-2026: «tiene que ser mucho más fácil e
# intuitivo para alguien que no es de sistemas»). Contesta las tres preguntas que se hace el admin:
#
#   1. ¿Está listo? Los pasos de «Armá tu portal», cada uno hecho o no, deducidos de lo que ya hay
#      cargado (no hay un «paso completado» guardado que pueda mentir).
#   2. ¿Qué espera que conteste? Pedidos de Reservar, mensajes sin responder y renovaciones del
#      REPROCANN que subieron los pacientes.
#   3. ¿Quiénes entran? El padrón partido en entran / invitados sin entrar / sin invitar / sin mail,
#      con los ids de los que se pueden invitar desde acá (la invitación es `InvitarEnLote`).
#
# Los números salen de los mismos scopes que usan las pantallas de cada cosa (`Reserva.solicitadas`,
# `ConversacionPaciente.sin_responder`, `ReprocannRenovacion.activas`): si la campanita dice 3
# pedidos, acá también.
module Portal
  class Panel
    MUESTRA = 3

    def self.de(club) = new(club).call

    def initialize(club)
      @club = club
    end

    def call
      pac = pacientes
      {
        contratado:   @club.feature?(:vista_paciente),
        abierto:      @club.vista_paciente_activa?,
        reservar:     @club.portal_reservar_activo?,
        mensajes:     @club.portal_mensajes_activo?,
        pasos:        pasos(pac),
        para_atender: para_atender,
        pacientes:    pac,
        publicado:    publicado,
        link_entrada: "#{App.base_url}/paciente/#{@club.slug}",
      }
    end

    private

    def pasos(pac)
      {
        abierto:      @club.vista_paciente_activa?,
        presentacion: [@club.descripcion_web, @club.horarios_atencion, @club.whatsapp].any?(&:present?),
        contenido:    @club.geneticas.where(visible_paciente: true).exists? || @club.noticias.publicadas.exists?,
        invitados:    pac[:entran].positive? || pac[:invitados_sin_entrar].positive?,
      }
    end

    # El padrón que puede tener portal: pacientes de alta y aprobados.
    def pacientes
      base       = @club.pacientes.where(es_paciente: true).aprobados
      ids        = base.pluck(:id)
      con_mail   = base.where.not(email: [nil, '']).pluck(:id).to_set
      activados  = AccesoPortal.where(paciente_id: ids).where.not(usado_at: nil).distinct.pluck(:paciente_id).to_set
      invitados  = AccesoPortal.where(paciente_id: ids).distinct.pluck(:paciente_id).to_set
      sin_entrar = ids.reject { |id| activados.include?(id) }

      sin_entrar_invitados = sin_entrar.select { |id| invitados.include?(id) }
      sin_invitar          = sin_entrar.reject { |id| invitados.include?(id) }
      {
        total:                ids.size,
        entran:               activados.size,
        invitados_sin_entrar: sin_entrar_invitados.size,
        sin_invitar:          sin_invitar.size,
        sin_mail:             sin_entrar.count { |id| !con_mail.include?(id) },
        # Los que se pueden invitar (o volver a invitar) por mail desde el panel.
        ids_recordar:         sin_entrar_invitados.select { |id| con_mail.include?(id) },
        ids_invitar:          sin_invitar.select { |id| con_mail.include?(id) },
      }
    end

    def para_atender
      pedidos = @club.reservas.solicitadas.includes(:paciente, items: { stock: [:sede, :genetica, { lote: :genetica }] })
                     .order(:created_at)
      convs   = ConversacionPaciente.where(club_id: @club.id).sin_responder.includes(:paciente).order(ultimo_mensaje_at: :desc)
      renovs  = ReprocannRenovacion.where(club_id: @club.id).del_portal.activas.includes(:paciente).recientes
      {
        pedidos: {
          total: pedidos.count,
          items: pedidos.first(MUESTRA).map do |r|
            { id: r.id, paciente_id: r.paciente_id, paciente: r.paciente&.nombre_completo,
              fecha: r.fecha_entrega_estimada, sede: r.items.first&.stock&.sede&.nombre,
              detalle: r.items.map { |i| "#{Portal::Catalogo.genetica(i.stock)&.nombre || i.stock&.forma_producto} #{fmt(i.cantidad)} #{i.stock&.unidad}".strip }.join(' + ') }
          end,
        },
        mensajes: {
          total: convs.count,
          items: convs.first(MUESTRA).map { |c| { paciente_id: c.paciente_id, paciente: c.paciente&.nombre_completo, at: c.ultimo_mensaje_at } },
        },
        renovaciones: {
          total: renovs.count,
          items: renovs.first(MUESTRA).map { |r| { paciente_id: r.paciente_id, paciente: r.paciente&.nombre_completo, at: r.created_at } },
        },
      }
    end

    def publicado
      ultima  = @club.noticias.para_web.first
      proximo = @club.eventos.para_web.first
      {
        geneticas:     @club.geneticas.where(visible_paciente: true).count,
        noticias:      @club.noticias.publicadas.count,
        ultima_noticia: ultima && { titulo: ultima.titulo, at: ultima.publicada_at },
        eventos:       @club.eventos.para_web.count,
        proximo_evento: proximo && { titulo: proximo.titulo, at: proximo.fecha_inicio },
        presentacion:  [@club.descripcion_web, @club.horarios_atencion, @club.whatsapp].any?(&:present?),
      }
    end

    def fmt(n) = n.to_f.round(2).to_s.sub(/\.0+\z/, '').tr('.', ',')
  end
end
