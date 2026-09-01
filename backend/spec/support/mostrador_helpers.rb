# Abrir el mostrador de una sede con todo su stock arriba.
#
# Los specs donde dispensa un DISPENSADOR lo necesitan por la misma razón que lo necesita la
# persona real: él dispensa de lo que está sobre la mesa, no del depósito. Un spec que dispensa
# sin abrir el mostrador estaría probando un camino que en producción no existe.
# (El admin y el supervisor son administración: dispensan del depósito, con o sin turno abierto.)
module MostradorHelpers
  # Deja el mostrador LISTO PARA ATENDER: abierto y recibido.
  #
  # Son los dos pasos que da la gente real. Si lo abre un admin (`usuario`), alguien que atiende
  # tiene que recibirlo (`recibe`): sin ese punto de partida verificado, el arqueo del cierre no
  # mide nada. Si lo abre el propio dispensador, ya queda confirmado solo.
  def abrir_mostrador!(sede, usuario:, recibe: nil, fondo: 0)
    ActsAsTenant.with_tenant(sede.club) do
      items = sede.club.stocks.where(sede_id: sede.id).select(&:apto_dispensa?).filter_map do |s|
        disp = s.cantidad_disponible_real.to_d
        { stock_id: s.id, cantidad: disp } if disp.positive?
      end
      res = Mostradores::AbrirTurno.call(mostrador: sede.mostrador!, usuario: usuario,
                                        items: items, monto_inicial_ars: fondo)
      raise "No se pudo abrir el mostrador: #{res.error}" unless res.ok?

      turno = res.turno
      unless turno.confirmado?
        # Quien cargó la mesa no puede recibírsela a sí mismo (serían dos firmas de la misma
        # persona), así que el receptor es otro: el que el spec indique, alguien del club que
        # atienda, o uno creado al vuelo.
        receptor = recibe ||
                   sede.club.users.where(role: 'dispensador').where.not(id: usuario.id).first ||
                   FactoryBot.create(:user, :dispensador, club: sede.club)
        conf = Mostradores::ConfirmarApertura.call(turno: turno, usuario: receptor)
        raise "No se pudo confirmar el mostrador: #{conf.error}" unless conf.ok?
      end
      turno.reload
    end
  end
end

RSpec.configure { |c| c.include MostradorHelpers }
