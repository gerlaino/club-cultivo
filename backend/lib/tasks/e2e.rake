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
      # El del teléfono de cultivo: el «+» con «Regar» sólo se le ofrece a él (y en uso personal).
      usuario_e2e!(club, 'cultivador',  'Cata', 'Cultivo')
      # Para la suite de humo por rol (20-oct-2026): cada rol recorre lo suyo.
      usuario_e2e!(club, 'manicura',    'Mica', 'Manicura')
      medico = usuario_e2e!(club, 'medico', 'Marta', 'Médica')

      sede = club.sedes.first || Sede.create!(club: club, created_by: admin, nombre: 'Sede E2E',
                                              tipo: 'mixta', direccion: 'Calle Falsa 123', activa: true)
      sala = club.salas.first || Sala.create!(club: club, sede: sede, nombre: 'Sala E2E',
                                              kind: 'floracion', created_by: admin)
      # Por NOMBRE, no «la primera»: otros escenarios (`e2e:cultivo`) dejan sus propias
      # genéticas y lotes en la org, y `.first` traía «E2E Haze» a una prueba que espera Kush.
      gen  = club.geneticas.find_by(nombre: 'E2E Kush') ||
             Genetica.create!(club: club, nombre: 'E2E Kush')
      lote = club.lotes.find_by(codigo: 'L-E2E-001') ||
             Lote.create!(club: club, sala: sala, sede: sede, genetica: gen,
                          codigo: 'L-E2E-001', estado: 'floracion', start_date: 60.days.ago.to_date)

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
        pac.cuenta_corriente!.update!(limite_credito: 100_000)
      end

      # El médico ve SÓLO sus vinculados: uno, para que su ficha tenga a quién mostrar.
      pac0 = Paciente.find_by(club: club, dni: '90000000')
      if pac0
        pac0.update_columns(con_seguimiento_medico: true)
        MedicoPaciente.vincular!(medico: medico, paciente: pac0) unless MedicoPaciente.exists?(medico: medico, paciente: pac0)
      end

      puts "Club e2e ##{club.id} listo · sede ##{sede.id} · flor ##{flor.id} (1000 g)"
      puts "  admin · dispensador · delivery · cultivador · manicura · medico @e2e.test — clave #{CLAVE_E2E}"
    end
  end

  # Un AUTOCULTIVO aparte (`casa@e2e.test`), para la prueba que recorre sus pantallas buscando
  # palabras de organización (lote, sala, sede, códigos). No es la org `e2e`: es otra cuenta, del
  # plan personal, creada por la misma puerta que el autoregistro. Idempotente: si ya existe, sólo
  # le repone la clave y lo que falte (un espacio con una cama, plantas en vege y una cosecha).
  desc 'Crea o rehace el autocultivo de pruebas e2e (casa@e2e.test)'
  task autocultivo: :environment do
    user = ActsAsTenant.without_tenant { User.find_by(email: 'casa@e2e.test') }
    unless user
      Registros::CrearPersonal.new(nombre: 'Casa E2E', email: 'casa@e2e.test', password: CLAVE_E2E,
                                   acepta_terminos: true, mayor_de_edad: true).call
      user = ActsAsTenant.without_tenant { User.find_by!(email: 'casa@e2e.test') }
    end
    user.update!(password: CLAVE_E2E, password_confirmation: CLAVE_E2E)
    club = user.club
    # Confirmado y sin vencer: si no, a los 7 días la cuenta se pausa y la prueba falla por eso.
    club.update_columns(plan_activo_hasta: Time.zone.today + 30, activo: true)
    RegistroPersonal.where(club_id: club.id).update_all(confirmado_at: Time.current)

    ActsAsTenant.with_tenant(club) do
      sede = club.sedes.first
      sala = club.salas.find_by(nombre: 'Carpa E2E') ||
             Sala.create!(club: club, sede: sede, nombre: 'Carpa E2E', kind: 'vegetativo', m2: 1, created_by: user)
      gen  = club.geneticas.find_by(nombre: 'E2E Ananda') ||
             Genetica.create!(club: club, nombre: 'E2E Ananda')

      unless club.lotes.where(estado: 'vegetativo').exists?
        lote = Lote.new(club: club, sala: sala, sede: sede, genetica: gen, estado: 'vegetativo',
                        start_date: 20.days.ago.to_date, tamanio_maceta: 10, dias_vegetativo_objetivo: 30,
                        plants_count: 2)
        Lotes::Plantar.new(lote: lote, usuario: user, plantas: 2).call
      end
      unless club.lotes.where(estado: 'curado').exists?
        cos = Lote.new(club: club, sede: sede, genetica: gen, estado: 'curado', start_date: 120.days.ago.to_date,
                      plants_count: 1)
        Lotes::Plantar.new(lote: cos, usuario: user, plantas: 1).call
        Stock.create!(club: club, sede: sede, lote: cos, genetica: gen, origen: 'lote',
                      forma_producto: 'flor_seca', unidad: 'g', cantidad: 40, estado: 'asignado')
      end
      lote = club.lotes.find_by(estado: 'vegetativo')
      cos  = club.lotes.find_by(estado: 'curado')
      # Tres fotos de la primera planta, para «Cómo creció» (cada vez más verde).
      planta = lote.plants.order(:id).first
      if LoteFoto.where(lote_id: lote.id).none?
        [[15, 120], [8, 160], [1, 200]].each do |dias, verde|
          f = LoteFoto.new(club: club, lote: lote, plant: planta, user: user, tomada_el: dias.days.ago.to_date)
          f.imagen.attach(io: StringIO.new(png_liso(40, verde, 60)), filename: "dia-#{dias}.png", content_type: 'image/png')
          f.save!
        end
      end
      puts "Autocultivo e2e ##{club.id} · espacio ##{sala.id} · plantas ##{lote.id} · cosecha ##{cos.id} · planta ##{lote.plants.first.id}"
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
      abrir_mostrador_e2e!(club, sede: sede, stock: stock, admin: admin, mesa_g: 100)

      puts 'Beto cobró $100.000 en 2 entregas y trae 1 paquete de 25 g sin entregar'
      puts 'Mostrador abierto con 100 g y $20.000, recibido por Dana'
    end
  end

  # La caja del mostrador ABIERTA con 300 g de flor sobre la mesa y $20.000 de fondo, para la
  # prueba de la dispensa con cobro (21-oct-2026). Abrir la caja contando ya lo prueba
  # `mostrador.spec`: acá es sólo el punto de partida.
  desc 'Mesa cargada y caja abierta por la dispensadora e2e'
  task caja_abierta: :environment do
    club = ActsAsTenant.without_tenant { Club.unscoped.find_by(slug: SLUG_E2E) }
    abort 'Corré antes rake e2e:seed' if club.nil?

    ActsAsTenant.with_tenant(club) do
      sede  = club.sedes.first
      stock = club.stocks.where(sede_id: sede.id, forma_producto: 'flor_seca').first
      abrir_mostrador_e2e!(club, sede: sede, stock: stock, admin: User.find_by(email: 'admin@e2e.test'), mesa_g: 300)
      puts 'Mostrador abierto con 300 g y $20.000, recibido por Dana'
    end
  end

  # Un paquete EN VIAJE que se cobra al entregar: es el único estado desde el que se ve el panel
  # de cobro del modal de entrega, que es donde vivía la tarjeta de "tu próxima entrega" pegada
  # por error. Los del `reparto` ya vienen cobrados y ese panel no aparece.
  desc 'Pone al repartidor e2e con un paquete en viaje a cobrar contra entrega'
  task entrega_a_cobrar: :environment do
    club = ActsAsTenant.without_tenant { Club.unscoped.find_by(slug: SLUG_E2E) }
    abort 'Corré antes rake e2e:seed' if club.nil?

    ActsAsTenant.with_tenant(club) do
      admin = User.find_by(email: 'admin@e2e.test')
      rep   = User.find_by(email: 'delivery@e2e.test')
      sede  = club.sedes.first
      stock = club.stocks.where(sede_id: sede.id, forma_producto: 'flor_seca').first
      pac   = club.pacientes.order(:id).last

      d = Dispensacion.create!(paciente: pac, user: admin, stock: stock, sede: sede,
                               cantidad: 5, medio_pago: 'efectivo', aporte_socio_ars: 212_500,
                               fecha_dispensacion: Time.zone.today, con_envio: true,
                               cobrar_en_entrega: true, delivery_id: rep.id,
                               direccion_envio: 'Calle 500', contacto_nombre: pac.nombre)
      d.update!(estado_envio: 'en_viaje')

      puts "Paquete #{d.codigo_paquete} en viaje, a cobrar $212.500 contra entrega"
    end
  end

  # El portal del paciente (27-oct-2026): la organización e2e con el portal contratado y abierto, y
  # Paciente2 (DNI 90000002) sin cuenta ni links, para que la prueba haga el camino entero:
  # invitarlo desde la ficha, abrir el link, elegir la clave y volver a entrar con el DNI.
  desc 'Portal del paciente abierto y Paciente2 sin acceso todavía'
  task portal: :environment do
    club = ActsAsTenant.without_tenant { Club.unscoped.find_by!(slug: SLUG_E2E) }
    club.update!(features: club.features.merge('vista_paciente' => true), vista_paciente_activa: true)

    ActsAsTenant.with_tenant(club) do
      pac = Paciente.find_by!(dni: '90000002')
      pac.update_columns(aprobado_at: pac.aprobado_at || Time.current, es_paciente: true, deleted_at: nil)
      AccesoPortal.where(paciente_id: pac.id).delete_all
      # Sin conversación previa: el chat arranca vacío en cada corrida.
      ConversacionPaciente.where(paciente_id: pac.id).destroy_all
      if (user = pac.user)
        pac.update_column(:user_id, nil)
        user.destroy!
      end

      # Una dispensa suya de la flor de L-E2E-001, con la historia del lote, un análisis y una
      # aplicación: lo que el detalle de «Mis dispensas» muestra como trazabilidad.
      admin = User.find_by!(email: 'admin@e2e.test')
      sede  = club.sedes.first
      flor  = club.stocks.find_by!(sede_id: sede.id, forma_producto: 'flor_seca')
      lote  = flor.lote
      flor.update_columns(fecha_elaboracion: 9.days.ago.to_date)
      unless lote.lote_eventos.where(tipo: 'cambio_estado').exists?
        { 'enraizado' => 90, 'vegetativo' => 76, 'floracion' => 60 }.each do |estado, hace|
          LoteEvento.create!(lote: lote, club: club, user: admin, tipo: 'cambio_estado', estado_nuevo: estado,
                             registrado_en: hace.days.ago, sala_destino: (estado == 'floracion' ? lote.sala : nil))
        end
      end
      AnalisisLaboratorio.find_or_create_by!(lote: lote, club_id: club.id, laboratorio: 'Laboratorio E2E') do |a|
        a.user = admin
        a.fecha_analisis = 12.days.ago.to_date
        a.thc_pct = 18.5
        a.cbd_pct = 0.4
      end
      d = Dispensacion.create!(paciente: pac, user: admin, stock: flor, sede: sede, cantidad: 5,
                               medio_pago: 'efectivo', aporte_socio_ars: 5_000, fecha_dispensacion: Time.zone.today)
      Dispensaciones::RegistrarCobro.call(dispensacion: d, club: club, usuario: admin, medio: 'efectivo', monto: 5_000)
      # Lo de la organización que el portal muestra: la genética publicada, la flor sobre la mesa
      # (el catálogo), un evento próximo para «Asistiré» y el REPROCANN por vencer (la renovación).
      lote.genetica&.update!(visible_paciente: true)
      flor.genetica&.update!(visible_paciente: true)
      mostrador = sede.mostrador!
      unless MostradorItem.where(mostrador_id: mostrador.id, stock_id: flor.id).where('cantidad > 0').exists?
        Mostradores::Cargar.call(mostrador: mostrador, usuario: admin, motivo: 'portal e2e', cambios: [{ stock_id: flor.id, cantidad: 100 }])
      end
      Evento.where(club_id: club.id, titulo: 'Taller e2e').destroy_all
      evento = Evento.create!(club: club, titulo: 'Taller e2e', fecha_inicio: 10.days.from_now.change(hour: 15), lugar: 'Sede E2E', activo: true)
      pac.update_columns(reprocann_numero: 'R-E2E', reprocann_vencimiento: 5.days.from_now.to_date, reprocann_estado: 'activo')
      ReprocannRenovacion.where(paciente_id: pac.id).delete_all
      puts "Portal e2e abierto · Paciente2 (#{pac.id}) sin cuenta · dispensa ##{d.id} · evento ##{evento.id}"
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

  StockMovimiento.unscoped.where(stock_id: stks).delete_all
  MovimientoContable.unscoped.where(ids).delete_all
  # `cuenta_corriente_movimientos` cuelga de la cuenta, no del club.
  CuentaCorrienteMovimiento.unscoped
                           .where(cuenta_corriente_id: CuentaCorriente.unscoped.where(ids).select(:id))
                           .delete_all
  # El saldo está GUARDADO en la cuenta, no se recalcula de los movimientos: sin esto la deuda de
  # la corrida anterior seguía ahí y cada corrida de `dispensaConCobro` debía el doble.
  CuentaCorriente.unscoped.where(ids).update_all(saldo_disponible: 0, saldo_disponible_g: 0)
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

# Un PNG de un solo color, sin gemas: alcanza para que una prueba tenga fotos que mostrar.
def png_liso(r, g, b, ancho = 64, alto = 48)
  chunk = ->(tipo, datos) { [datos.bytesize].pack('N') + tipo + datos + [Zlib.crc32(tipo + datos)].pack('N') }
  filas = ([0] + [r, g, b] * ancho).pack('C*') * alto
  "\x89PNG\r\n\x1a\n".b + chunk.('IHDR', [ancho, alto, 8, 2, 0, 0, 0].pack('NNCCCCC')) +
    chunk.('IDAT', Zlib::Deflate.deflate(filas)) + chunk.('IEND', '')
end

# Administración carga la mesa y quien atiende abre la caja contando: los dos pasos reales, de las
# dos personas. Antes anula lo que haya quedado abierto de otra corrida.
def abrir_mostrador_e2e!(club, sede:, stock:, admin:, mesa_g:)
  mostrador = sede.mostrador
  TurnoMostrador.abiertos.where(mostrador_id: mostrador.id).find_each do |t|
    t.update!(estado: 'anulado', cerrado_at: Time.current, cerrado_por: admin)
  end
  CajaTurno.where(club_id: club.id).activas.find_each { |c| c.update!(estado: 'anulada') }

  disp = User.find_by(email: 'dispensador@e2e.test')
  car = Mostradores::Cargar.call(mostrador: mostrador, usuario: admin, motivo: 'carga del día',
                                 cambios: [{ stock_id: stock.id, cantidad: mesa_g }])
  abort "No se pudo cargar la mesa: #{car.error}" unless car.ok?
  res = Mostradores::AbrirCaja.call(mostrador: mostrador, usuario: disp, efectivo_contado_ars: 20_000)
  abort "No se pudo abrir la caja: #{res.error}" unless res.ok?
end

def usuario_e2e!(club, rol, nombre, apellido)
  u = User.find_by(email: "#{rol}@e2e.test")
  return u.tap { |x| x.update!(password: CLAVE_E2E, password_confirmation: CLAVE_E2E) } if u

  User.create!(club: club, email: "#{rol}@e2e.test", first_name: nombre, last_name: apellido,
               role: rol, password: CLAVE_E2E, password_confirmation: CLAVE_E2E)
end
