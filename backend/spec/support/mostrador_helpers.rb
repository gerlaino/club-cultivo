# Deja el mostrador LISTO PARA ATENDER: con mercadería sobre la mesa y la caja abierta.
#
# Son los dos pasos de la vida real, y son de personas distintas:
#   · el ADMIN carga la mesa, cuando quiere y desde donde esté
#   · quien ATIENDE cuenta lo que hay y abre la caja
#
# Los specs donde dispensa un DISPENSADOR lo necesitan por la misma razón que lo necesita la
# persona real: él entrega de lo que está sobre la mesa y cobra en una caja abierta. Un spec que
# dispensa sin esto estaría probando un camino que en producción no existe.
# (El admin y el supervisor son administración: dispensan del depósito, con o sin caja abierta.)
module MostradorHelpers
  def abrir_mostrador!(sede, usuario:, recibe: nil, fondo: 0)
    ActsAsTenant.with_tenant(sede.club) do
      mostrador = sede.mostrador!
      cambios = sede.club.stocks.where(sede_id: sede.id).select(&:apto_dispensa?).filter_map do |s|
        disp = s.cantidad_disponible_real.to_d
        { stock_id: s.id, cantidad: disp } if disp.positive?
      end

      if cambios.any?
        res = Mostradores::Cargar.call(mostrador: mostrador, usuario: usuario, cambios: cambios,
                                       motivo: 'carga inicial del spec')
        raise "No se pudo cargar el mostrador: #{res.error}" unless res.ok?
      end

      # Abre quien vaya a atender. Si el spec no lo dice, abre el mismo que cargó: en la vida
      # real puede pasar (una organización de una sola persona) y el conteo de apertura vale
      # igual — lo que no puede pasar es que nadie pueda abrir.
      quien = recibe || usuario
      res = Mostradores::AbrirCaja.call(mostrador: mostrador, usuario: quien,
                                        efectivo_contado_ars: fondo)
      raise "No se pudo abrir la caja del mostrador: #{res.error}" unless res.ok?

      res.turno.reload
    end
  end

  # Lo que hay sobre la mesa de una sede, por stock. Para afirmar sin reconstruirlo a mano.
  def mesa_de(sede)
    ActsAsTenant.with_tenant(sede.club) do
      sede.mostrador!.sobre_la_mesa.each_with_object({}) { |mi, acc| acc[mi.stock_id] = mi.cantidad.to_f }
    end
  end
end

RSpec.configure { |c| c.include MostradorHelpers }
