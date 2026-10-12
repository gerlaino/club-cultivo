# CAMBIAR EL ROL DE ALGUIEN DEL EQUIPO, ENTERO (12-oct-2026, Germán: «chequear que al cambiar de
# rol a algún miembro del equipo se cambie todo como corresponde»).
#
# Antes el rol se cambiaba en una columna y el resto quedaba como estaba: las sedes de otro tipo,
# las salas de cultivo, las tareas que el rol nuevo ni ve, la caja que había abierto, los turnos de
# un médico que dejaba de serlo. La confirmación le pedía al admin «revisá sus asignaciones».
# Y la persona, con la app abierta, seguía viendo el menú viejo contra un backend que ya le
# contestaba 403.
#
# Ahora, en un solo lugar:
#   · BLOQUEA lo que no se puede dejar colgado: módulo, cupo del plan y despachos en la calle
#     (`CambioDeRol`), una caja abierta a su nombre y turnos médicos por venir.
#   · LIMPIA lo que deja de tener sentido: las sedes donde el rol nuevo no tiene nada que hacer
#     (`Sede::TIPOS_POR_ROL`), las salas asignadas si el rol nuevo no cultiva, las tareas activas
#     si el rol nuevo no tiene pantalla de tareas (quedan sin asignar, no se borran).
#   · AVISA a su sesión abierta (`Transmite`, recurso `usuarios`, acción `rol`): la app vuelve a
#     pedir /me y lo lleva a su inicio.
#
# `efectos` dice todo eso ANTES, para que la confirmación lo muestre; `call!` lo hace.
# El historial no se toca: dispensas, turnos, cobros y auditoría siguen colgando del `user_id`.
module Acceso
  class CambiarRol
    include CambioDeRol

    Bloqueado = Class.new(StandardError) do
      attr_reader :status
      def initialize(mensaje, status = :unprocessable_entity)
        @status = status
        super(mensaje)
      end
    end

    ROLES_CON_SALAS  = %w[cultivador manicura supervisor].freeze
    ROLES_SIN_TAREAS = %w[delivery medico abogado auditor paciente].freeze

    def initialize(user:, nuevo_rol:, por:, sede_ids: nil)
      @user      = user
      @club      = user.club
      @nuevo     = nuevo_rol.to_s
      @por       = por
      @sede_ids  = sede_ids&.map(&:to_i)
    end

    def cambia? = @nuevo.present? && @nuevo != @user.role

    # { bloqueos: [String], cambios: [String] } — lo que la confirmación muestra.
    def efectos
      return { bloqueos: [], cambios: [] } unless cambia?

      { bloqueos: bloqueos.map(&:first), cambios: cambios }
    end

    def call!
      return @user unless cambia?
      if (b = bloqueos.first)
        raise Bloqueado.new(b.first, b.last)
      end
      sedes_a_quitar # se calcula con el rol de antes, que es el que importa

      User.transaction do
        # Primero el rol: la asignación de una sede se valida contra el rol de la persona.
        @user.update!(role: @nuevo)
        quitar_sedes!
        asignar_sedes!
        quitar_salas!
        liberar_tareas!
      end
      Transmite.emitir(@club.id, recurso: 'usuarios', accion: 'rol', id: @user.id)
      @user
    end

    private

    def label(rol) = Club::ROLES_META.dig(rol.to_s, :label) || rol.to_s

    # [[mensaje, status]]
    def bloqueos
      @bloqueos ||= begin
        out = []
        if (rechazo = rechazo_cambio_de_rol(@club, @user, @nuevo))
          status, payload = rechazo
          out << [Array(payload[:errors]).first || payload[:mensaje] || payload[:error] || 'El plan no permite ese rol.', status]
        end
        caja = CajaTurno.activas.where(club_id: @club.id, abierta_por_id: @user.id).includes(:sede).first
        if caja && @nuevo != 'dispensador'
          out << ["#{@user.first_name} tiene abierta la caja de #{caja.sede&.nombre}. Que la cierre antes de cambiarle el rol: " \
                  "si no, queda una caja que nadie puede cerrar.", :unprocessable_entity]
        end
        if @user.role == 'medico'
          futuros = Turno.where(club_id: @club.id, medico_id: @user.id).where('fecha_hora >= ?', Time.current)
                         .where.not(estado: %w[cancelado realizado]).count
          if futuros.positive?
            out << ["#{@user.first_name} tiene #{futuros} turno#{futuros == 1 ? '' : 's'} por venir. Reasignalos o cancelalos " \
                    'antes de cambiarle el rol: los pacientes quedarían citados con alguien que ya no atiende.', :unprocessable_entity]
          end
        end
        out
      end
    end

    def cambios
      out = ["Pasa de #{label(@user.role)} a #{label(@nuevo)}: sus permisos y su menú cambian en el acto, también si tiene la app abierta."]
      sacar = sedes_a_quitar
      if sacar.any?
        quedan = @user.sedes_asignadas.where.not(id: sacar.map(&:id)).count
        out << "Deja de estar asignado a #{sacar.map(&:nombre).to_sentence(locale: :es)}: " \
               "#{label(@nuevo)} no tiene nada que hacer en una sede de ese tipo." +
               (quedan.zero? && @sede_ids.blank? ? ' Sin sedes asignadas, va a ver toda la organización.' : '')
      end
      salas = salas_a_quitar
      out << "Deja de tener #{salas} sala#{salas == 1 ? '' : 's'} de cultivo asignada#{salas == 1 ? '' : 's'}." if salas.positive?
      tareas = tareas_a_liberar
      out << "Sus #{tareas} tarea#{tareas == 1 ? '' : 's'} activa#{tareas == 1 ? '' : 's'} quedan sin asignar: #{label(@nuevo)} no tiene pantalla de tareas." if tareas.positive?
      out << 'Su historial (lo que hizo) se conserva tal cual.'
      out
    end

    def tipos_permitidos = Sede.tipos_para_rol(@nuevo)

    def sedes_a_quitar
      @sedes_a_quitar ||= @user.sedes_asignadas.reject { |s| tipos_permitidos.include?(s.tipo) }
    end

    def quitar_sedes!
      ids = sedes_a_quitar.map(&:id)
      UserSede.where(user_id: @user.id, sede_id: ids).destroy_all if ids.any?
    end

    # Las sedes que eligió el admin para el rol nuevo, si eligió: sólo las de la organización y
    # del tipo que el rol atiende. Reemplazan a las que tenía.
    def asignar_sedes!
      return if @sede_ids.nil?

      validas = @club.sedes.where(id: @sede_ids, tipo: tipos_permitidos).pluck(:id)
      UserSede.where(user_id: @user.id).where.not(sede_id: validas).destroy_all
      validas.each { |sid| UserSede.find_or_create_by!(user_id: @user.id, sede_id: sid) }
    end

    def salas_a_quitar
      return 0 if ROLES_CON_SALAS.include?(@nuevo)
      @user.sala_cultivadores.count
    end

    def quitar_salas!
      @user.sala_cultivadores.destroy_all unless ROLES_CON_SALAS.include?(@nuevo)
    end

    def tareas_a_liberar
      return 0 unless ROLES_SIN_TAREAS.include?(@nuevo)
      Tarea.del_club(@club.id).activas.where(asignada_a_id: @user.id).count
    end

    def liberar_tareas!
      return unless ROLES_SIN_TAREAS.include?(@nuevo)
      Tarea.del_club(@club.id).activas.where(asignada_a_id: @user.id).find_each { |t| t.update!(asignada_a_id: nil) }
    end
  end
end
