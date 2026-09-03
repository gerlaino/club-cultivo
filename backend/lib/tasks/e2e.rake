# Datos para las pruebas de punta a punta del navegador.
#
# Una organización APARTE, reconocible y descartable: `slug: 'e2e'`. Nunca toca los clubes reales
# —probar sobre datos de verdad es cómo se rompe una base de desarrollo— y es idempotente.
#
# REUSA el club en vez de borrarlo y rehacerlo: borrarlo de verdad choca con las FKs de
# `auditorias`, que no se borran a propósito (el rastro de quién hizo qué sobrevive al registro).
# Lo que se limpia en cada corrida es lo OPERATIVO — turnos, rendiciones, dispensas, stock.
#
#   docker compose exec backend bundle exec rake e2e:seed
#   docker compose exec backend bundle exec rake e2e:limpiar
namespace :e2e do
  CLAVE_E2E = 'E2eTest2026!'.freeze
  SLUG_E2E  = 'e2e'.freeze

  desc 'Crea o rehace la organización de pruebas e2e (idempotente)'
  task seed: :environment do
    club = ActsAsTenant.without_tenant { Club.unscoped.find_by(slug: SLUG_E2E) }
    club = crear_club_e2e! if club.nil?
    club.update_columns(deleted_at: nil) if club.deleted_at

    ActsAsTenant.with_tenant(club) do
      limpiar_operativo_e2e!(club)

      admin = usuario_e2e!(club, 'admin',       'Ada',  'Admin')
      usuario_e2e!(club, 'dispensador', 'Dana', 'Dispensa')
      usuario_e2e!(club, 'delivery',    'Beto', 'Reparto')

      sede = club.sedes.first || Sede.create!(club: club, created_by: admin, nombre: 'Sede E2E',
                                              tipo: 'mixta', direccion: 'Calle Falsa 123', activa: true)
      sala = club.salas.first || Sala.create!(club: club, sede: sede, nombre: 'Sala E2E',
                                              kind: 'floracion', created_by: admin)
      gen  = club.geneticas.where.not(club_id: nil).first ||
             Genetica.create!(club: club, nombre: 'E2E Kush', created_by: admin)
      lote = club.lotes.first || Lote.create!(club: club, sala: sala, sede: sede, genetica: gen,
                                              codigo: 'L-E2E-001', estado: 'floracion',
                                              start_date: 60.days.ago.to_date)

      # Dos productos: la flor va a la mesa, el preroll queda en el depósito. El segundo existe
      # para probar que el carrito del dispensador SÓLO ofrece lo que está arriba.
      flor = Stock.create!(club: club, sede: sede, lote: lote, genetica: gen, origen: 'lote',
                           forma_producto: 'flor_seca', unidad: 'g', cantidad: 1_000,
                           estado: 'asignado', disponibilidad: 'ambas',
                           costo_unitario_ars: 500, precio_sugerido_ars: 1_000)
      Stock.create!(club: club, sede: sede, genetica: gen, origen: 'compra_externa',
                    proveedor: 'E2E', forma_producto: 'preroll', unidad: 'un', cantidad: 100,
                    estado: 'asignado', disponibilidad: 'ambas',
                    costo_unitario_ars: 800, precio_sugerido_ars: 2_000)

      3.times do |i|
        next if Paciente.unscoped.where(club_id: club.id, dni: "9000000#{i}").exists?

        pac = Paciente.create!(club: club, nombre: "Paciente#{i}", apellido: 'E2E',
                               dni: "9000000#{i}", email: "paciente#{i}@e2e.test",
                               fecha_nacimiento: 30.years.ago.to_date, created_by: admin)
        CuentaCorriente.create!(club: club, paciente: pac, saldo_disponible: 0, limite_credito: 100_000)
      end

      puts "Club e2e ##{club.id} listo · sede ##{sede.id} · flor ##{flor.id} (1000 g)"
      puts "  admin@e2e.test · dispensador@e2e.test · delivery@e2e.test — clave #{CLAVE_E2E}"
    end
  end

  # Deja al repartidor con plata cobrada en la calle y un paquete sin entregar, que es el estado
  # desde el que arranca la prueba de la rendición. Hacerlo por la app llevaría media prueba
  # armando el escenario en vez de probar lo que interesa.
  desc 'Pone al repartidor e2e con recaudación y un paquete sin entregar'
  task reparto: :environment do
    club = ActsAsTenant.without_tenant { Club.unscoped.find_by(slug: SLUG_E2E) }
    abort 'Corré antes rake e2e:seed' if club.nil?

    ActsAsTenant.with_tenant(club) do
      admin = User.find_by(email: 'admin@e2e.test')
      rep   = User.find_by(email: 'delivery@e2e.test')
      sede  = club.sedes.first
      stock = club.stocks.where(sede_id: sede.id, forma_producto: 'flor_seca').first
      pacs  = club.pacientes.order(:id).to_a

      [60_000, 40_000].each_with_index do |monto, i|
        d = Dispensacion.create!(paciente: pacs[i], user: admin, stock: stock, sede: sede,
                                 cantidad: 5, medio_pago: 'efectivo', aporte_socio_ars: monto,
                                 fecha_dispensacion: Time.zone.today, con_envio: true,
                                 delivery_id: rep.id, direccion_envio: "Calle #{100 + i}",
                                 contacto_nombre: pacs[i].nombre)
        Dispensaciones::RegistrarCobro.call(dispensacion: d, club: club, usuario: rep,
                                            medio: 'efectivo', monto: monto, contexto: 'entrega')
      end

      f = Dispensacion.create!(paciente: pacs[2], user: admin, stock: stock, sede: sede,
                               cantidad: 25, medio_pago: 'efectivo', aporte_socio_ars: 25_000,
                               fecha_dispensacion: Time.zone.today, con_envio: true,
                               delivery_id: rep.id, direccion_envio: 'Calle 300',
                               contacto_nombre: pacs[2].nombre)
      f.update!(estado_envio: 'fallido', motivo_fallo: 'no había nadie', fallido_at: Time.current)

      # Y el mostrador ABIERTO y RECIBIDO, que es donde la plata y el producto tienen que entrar.
      # Lo deja el rake y no la prueba: armar el escenario a través de la pantalla haría que un
      # fallo del setup se lea como un fallo de lo que se está probando.
      mostrador = sede.mostrador
      TurnoMostrador.abiertos.where(mostrador_id: mostrador.id).find_each do |t|
        t.update!(estado: 'anulado', cerrado_at: Time.current, cerrado_por: admin)
      end
      CajaTurno.where(club_id: club.id).activas.find_each { |c| c.update!(estado: 'anulada') }

      disp = User.find_by(email: 'dispensador@e2e.test')
      # Los dos pasos reales, de las dos personas: administración carga la mesa y quien atiende
      # abre la caja contando lo que encuentra.
      car = Mostradores::Cargar.call(mostrador: mostrador, usuario: admin, motivo: 'carga del día',
                                     cambios: [{ stock_id: stock.id, cantidad: 100 }])
      abort "No se pudo cargar la mesa: #{car.error}" unless car.ok?
      res = Mostradores::AbrirCaja.call(mostrador: mostrador, usuario: disp,
                                        efectivo_contado_ars: 20_000)
      abort "No se pudo abrir la caja: #{res.error}" unless res.ok?

      puts 'Beto cobró $100.000 en 2 entregas y trae 1 paquete de 25 g sin entregar'
      puts 'Mostrador abierto con 100 g y $20.000, recibido por Dana'
    end
  end

  desc 'Deja la organización e2e sin datos operativos'
  task limpiar: :environment do
    club = ActsAsTenant.without_tenant { Club.unscoped.find_by(slug: SLUG_E2E) }
    next puts('No hay club e2e') if club.nil?

    ActsAsTenant.with_tenant(club) { limpiar_operativo_e2e!(club) }
    puts "Club e2e ##{club.id} limpio"
  end
end

def crear_club_e2e!
  # `without_tenant`: al crear un club corre `crear_geneticas_default!`, que consulta `Genetica`
  # —modelo tenant con `require_tenant`— y sin esto revienta con NoTenantSet.
  ActsAsTenant.without_tenant do
    Club.create!(name: 'Organización E2E', slug: 'e2e', plan: 'total',
                 features: { 'produccion_dispensa' => true, 'cultivo' => true, 'delivery' => true })
  end
end

# Del más dependiente al menos. El orden importa y no es obvio: `stock_movimientos` apunta al
# stock, a la dispensación Y al turno de mostrador, así que va antes que los tres.
def limpiar_operativo_e2e!(club)
  ids   = { club_id: club.id }
  disps = Dispensacion.unscoped.joins(:paciente).where(pacientes: ids).select(:id)
  stks  = Stock.unscoped.where(ids).select(:id)

  TurnoMostradorMovimiento.unscoped.where(ids).delete_all
  StockMovimiento.unscoped.where(stock_id: stks).delete_all
  MovimientoContable.unscoped.where(ids).delete_all
  # `cuenta_corriente_movimientos` cuelga de la cuenta, no del club.
  CuentaCorrienteMovimiento.unscoped
                           .where(cuenta_corriente_id: CuentaCorriente.unscoped.where(ids).select(:id))
                           .delete_all
  Cobro.unscoped.where(ids).delete_all
  DispensacionItem.unscoped.where(dispensacion_id: disps).delete_all
  Reserva.unscoped.where(ids).delete_all
  Dispensacion.unscoped.where(id: disps).delete_all
  # La mesa y su historial: los movimientos cuelgan del ítem, así que van antes.
  MostradorMovimiento.unscoped.where(ids).delete_all
  MostradorItem.unscoped.where(ids).delete_all
  TurnoMostradorItem.unscoped.where(ids).delete_all
  TurnoMostrador.unscoped.where(ids).delete_all
  RendicionCaja.unscoped.where(ids).delete_all
  CajaTurno.unscoped.where(ids).delete_all
  Stock.unscoped.where(ids).delete_all
end

def usuario_e2e!(club, rol, nombre, apellido)
  u = User.find_by(email: "#{rol}@e2e.test")
  return u.tap { |x| x.update!(password: CLAVE_E2E, password_confirmation: CLAVE_E2E) } if u

  User.create!(club: club, email: "#{rol}@e2e.test", first_name: nombre, last_name: apellido,
               role: rol, password: CLAVE_E2E, password_confirmation: CLAVE_E2E)
end
