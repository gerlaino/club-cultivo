module Rendiciones
  # DÓNDE ENTRA EL EFECTIVO QUE SE RECIBE DEL REPARTIDOR.
  #
  # Lo preguntan las DOS puertas por las que esa plata entra al club: la rendición que arranca él
  # (la tarjeta del mostrador) y el "Recibir caja" de su ficha, que usa el admin cuando el
  # repartidor se fue sin rendir. Escrita dos veces, un día una deja pasar lo que la otra rechaza
  # — y lo que está en juego es en qué cajón cae la plata.
  class DestinoEfectivo
    # Quién elige. El dispensador no: el efectivo cae en la caja de SU mostrador.
    GESTIONAN = %w[admin supervisor super_admin].freeze

    # Los mostradores con la caja abierta que esta persona puede elegir, con quién la abrió y
    # desde cuándo: elegir un cajón a ciegas es elegir mal.
    def self.cajas_abiertas_para(user)
      return [] unless GESTIONAN.include?(user.role)

      CajaTurno.unscoped
               .where(club_id: user.club_id, estado: 'abierta', sede_id: user.sedes_visibles_ids)
               .de_mostradores.includes(:sede, :abierta_por)
               .map { |c| { sede_id: c.sede_id, sede: c.sede&.nombre,
                            abierta_por: c.abierta_por&.nombre_completo, desde: c.abierta_at } }
    end

    # EL EFECTIVO ENTRA A UNA CAJA, Y SI SE LO LLEVA LO SACA DEL CAJÓN.
    #
    # "Queda en la organización" dejaba plata asentada que ningún arqueo reclama y que nadie tiene
    # a su nombre. Entrando al cajón y saliendo por un retiro son DOS registros —quién la recibió
    # y quién se la llevó— en vez de una desaparición: el retiro ya existe, queda a nombre de la
    # persona y se salda cuando la trae. (Decisión de Germán, sep-2026.)
    #
    # Sólo se acepta la organización cuando NO hay ninguna caja abierta donde ponerla: obligar ahí
    # dejaría al repartidor volviéndose a su casa con la recaudación, que es peor que todo esto.
    def self.error_de(destino, user)
      return nil unless destino.to_s == Recibir::DESTINO_CLUB
      return nil if cajas_abiertas_para(user).empty?

      'El efectivo tiene que entrar a una caja: elegí el mostrador. Si te lo vas a llevar, ' \
        'sacalo del cajón después y queda registrado a tu nombre.'
    end
  end
end
