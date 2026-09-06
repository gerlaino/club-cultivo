module Mostradores
  # LAS TRES RAZONES por las que un turno pide una mirada, y NADA MÁS las decide.
  #
  # Estaba escrito DOS VECES: en SQL, en el controller, sólo para contar el número del badge; y en
  # Ruby, adentro de `Mostradores::Merma`, para armar la lista con el detalle. Coincidían — se
  # verificó antes de unificarlas —, pero es exactamente el patrón que en este proyecto siempre
  # terminó divergiendo (la matriz de rutas por rol, el estado del lote contra el tipo de sala):
  # alguien toca una copia y no la otra, y el badge dice 3 mientras la lista muestra 2.
  #
  #   · faltante     → faltó producto al contar el cierre
  #   · sobrante     → contó MÁS de lo que había, al abrir o al cerrar. Si lo contó quien
  #                    atiende, no se aplicó (contar no crea producto de la nada): ni el
  #                    inventario al cerrar, ni la mesa al abrir. Administración decide si ese
  #                    producto se carga de verdad, por su puerta, que descuenta del depósito.
  #   · corregido    → quien abrió corrigió HACIA ABAJO lo que decía la mesa
  #   · mesa_movida  → administración cargó o retiró mientras la caja estaba abierta
  #
  # Sigue en SQL y no trae los turnos a Ruby: el badge se pide en CADA carga de la pantalla del
  # mostrador, y recorrer los ítems de todos los turnos pendientes en cada request sería pagar por
  # un dato que casi siempre es cero.
  class MotivosDeRevision
    RAZONES = %w[faltante sobrante corregido mesa_movida].freeze

    # `candidatos`: relación de `TurnoMostrador` YA FILTRADA (cerrados, el rango que corresponda).
    # Devuelve `{ turno_id => ['faltante', 'mesa_movida', ...] }` — sólo con los que tienen AL
    # MENOS una razón no aparecen en el hash, así que `.size` es directamente el conteo del badge.
    def self.por_turno(candidatos)
      ids = candidatos.select(:id)
      items = TurnoMostradorItem.where(turno_mostrador_id: ids)

      contados     = items.where.not(cantidad_cierre: nil).where.not(esperado_cierre: nil)
      aperturas    = items.where.not(esperado_apertura: nil)
      con_faltante = contados.where('cantidad_cierre < esperado_cierre')
                             .distinct.pluck(:turno_mostrador_id).to_set
      # El sobrante es el mismo hecho contado en los DOS momentos —al abrir o al cerrar—, y por
      # eso es una sola razón: "contó más de lo que decía la mesa". Lo de la apertura no es una
      # corrección, porque la mesa no se movió (ver `AbrirCaja#sobrante_sin_aplicar?`).
      con_sobrante = (contados.where('cantidad_cierre > esperado_cierre')
                              .distinct.pluck(:turno_mostrador_id) +
                      aperturas.where('cantidad_apertura > esperado_apertura')
                               .distinct.pluck(:turno_mostrador_id)).to_set
      # `corregido` es la mesa que efectivamente CAMBIÓ al abrir, y sólo cambia hacia abajo: lo
      # que no está, no está. Hacia arriba ya está contemplado arriba como sobrante.
      corregidos   = aperturas.where('cantidad_apertura < esperado_apertura')
                              .distinct.pluck(:turno_mostrador_id).to_set
      # Alguien movió la mesa mientras la caja estaba abierta: no es sospechoso por sí solo, pero
      # explica una diferencia que si no aparece como merma de quien atendió.
      mesa_movida  = MostradorMovimiento.where(turno_mostrador_id: ids, tipo: %w[carga retiro])
                                        .distinct.pluck(:turno_mostrador_id).to_set

      (con_faltante | con_sobrante | corregidos | mesa_movida).index_with do |id|
        [
          ('faltante'    if con_faltante.include?(id)),
          ('sobrante'    if con_sobrante.include?(id)),
          ('corregido'   if corregidos.include?(id)),
          ('mesa_movida' if mesa_movida.include?(id)),
        ].compact
      end
    end
  end
end
