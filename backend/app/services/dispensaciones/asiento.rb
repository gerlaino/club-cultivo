module Dispensaciones
  # EL ASIENTO DE LO QUE SE COBRA POR UNA DISPENSA, partido entre producto y envío (23-sep-2026).
  #
  # Lo escriben tres puertas —el cobro (`RegistrarCobro`), el medio de pago único
  # (`AplicarEfectos`) y la rendición del repartidor (`Rendiciones::Recibir`)— y las tres tienen
  # que partirlo igual: la parte del producto va a «Recupero dispensación» y la del envío, a
  # «Envíos». Escrito tres veces, un día dos de ellas dicen distinto.
  #
  # `attrs`: todo lo del movimiento menos la categoría y el monto (club, sede, fecha, medio,
  # pagado, descripción…). Devuelve los movimientos creados.
  module Asiento
    def self.crear!(dispensacion:, monto:, attrs:)
      envio     = dispensacion.parte_envio_de(monto)
      productos = monto.to_d - envio
      movs = []
      if productos > 0
        movs << MovimientoContable.create!(attrs.merge(dispensacion: dispensacion, tipo: attrs[:tipo] || 'recupero_costo',
                                                       categoria: 'dispensacion', monto_ars: productos))
      end
      if envio > 0
        movs << MovimientoContable.create!(attrs.merge(dispensacion: dispensacion, tipo: 'ingreso', categoria: 'envio',
                                                       monto_ars: envio, descripcion: "#{attrs[:descripcion]} — envío"))
      end
      movs
    end
  end
end
