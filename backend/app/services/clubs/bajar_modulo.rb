module Clubs
  # Apaga de verdad un módulo cuya baja ya venció, y deja ordenado lo que ese módulo dejaba
  # colgando.
  #
  # Apagar la bandera y nada más no alcanza: en Delivery, los repartidores dejan de poder entrar
  # (eso lo hace solo `check_rol_habilitado!`) pero los paquetes que tenían asignados quedarían
  # con un responsable que ya no puede abrir la app, y nadie se enteraría hasta que un paciente
  # reclame que no le llegó.
  class BajarModulo
    # Lo que ya salió a la calle se termina. Cortar un viaje en curso deja al repartidor con
    # producto de la organización y sin forma de registrar la entrega, que es peor que dejarlo
    # cerrar el reparto del día.
    ESTADOS_INTOCABLES = %w[en_viaje entregado fallido].freeze

    def self.call(club, clave) = new(club, clave).call

    def initialize(club, clave)
      @club  = club
      @clave = clave.to_s
    end

    def call
      resultado = { modulo: @clave, club_id: @club.id }

      ActiveRecord::Base.transaction do
        resultado.merge!(ordenar_delivery) if @clave == 'delivery'

        @club.update!(
          features:      @club.features.except(@clave),
          features_baja: @club.features_baja.except(@clave)
        )
      end

      Rails.logger.info("[MODULOS] baja aplicada: #{resultado.inspect}")
      resultado
    end

    private

    def ordenar_delivery
      # Sólo lo que todavía no arrancó. `en_viaje` se deja para que el repartidor pueda cerrarlo.
      # Club no tiene `dispensaciones` directo: cuelgan del paciente.
      pendientes = Dispensacion.joins(:paciente)
                               .where(pacientes: { club_id: @club.id })
                               .where.not(delivery_id: nil)
                               .where.not(estado_envio: ESTADOS_INTOCABLES)

      desasignados = pendientes.count
      # `update_all`: es una reasignación masiva, no queremos disparar callbacks de envío ni
      # notificar a un repartidor que ya no tiene acceso.
      pendientes.update_all(delivery_id: nil, updated_at: Time.current)

      avisar_reparto_sin_asignar(desasignados) if desasignados.positive?

      { desasignados: desasignados, repartidores: @club.users.where(role: 'delivery').count }
    end

    # El admin tiene que enterarse: son entregas que quedaron sin responsable y alguien las tiene
    # que resolver a mano.
    def avisar_reparto_sin_asignar(cantidad)
      AlertaInterna.create!(
        club_id:          @club.id,
        tipo:             'modulo_dado_de_baja',
        mensaje:          "El módulo Delivery se dio de baja. #{cantidad} " \
                          "#{cantidad == 1 ? 'entrega quedó' : 'entregas quedaron'} sin repartidor asignado: " \
                          'hay que resolverlas por otra vía.',
        severidad:        'warning',
        destinada_a_role: 'admin'
      )
    end
  end
end
