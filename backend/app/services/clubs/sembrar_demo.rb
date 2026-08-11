module Clubs
  # Genera un club MODELO: lleno de datos en todos los módulos, para mostrarle la app a alguien que
  # no la conoce. No es una copia de un club real —los pacientes reales tienen DNI, REPROCANN e
  # historia clínica, datos de salud que no pueden estar en una vidriera— sino data inventada.
  #
  # Y se genera en vez de copiarse por otra razón: un club real tiene tres lotes a medio cargar y
  # meses sin dispensar. Para mostrar, cada pantalla tiene que tener contenido y los gráficos tienen
  # que CONTAR ALGO: una genética que rinde claramente mejor, un mes flojo y una recuperación, un
  # lote que se perdió. Datos random uniformes dan gráficos planos que no muestran para qué sirve
  # la app.
  #
  # Es reproducible: se puede borrar y volver a generar cuando se toque el esquema o antes de una
  # demo importante.
  class SembrarDemo
    MESES_HISTORIA = 12

    # Cada genética con su carácter, para que la analítica muestre diferencias reales y no ruido.
    # `rinde` es gramos por planta y `merma` la proporción de plantas que se pierden.
    GENETICAS = [
      { nombre: 'Northern Lights',  thc: 18.0, cbd: 0.8, dias_flora: 56, rinde: 95, merma: 0.05 },
      { nombre: 'Critical Kush',    thc: 22.0, cbd: 0.5, dias_flora: 63, rinde: 120, merma: 0.08 },
      { nombre: 'CBD Charlotte',    thc: 0.6,  cbd: 16.0, dias_flora: 63, rinde: 70, merma: 0.10 },
      { nombre: 'Amnesia Haze',     thc: 21.0, cbd: 0.4, dias_flora: 77, rinde: 105, merma: 0.12 },
      { nombre: 'Blue Dream',       thc: 19.0, cbd: 1.2, dias_flora: 63, rinde: 88, merma: 0.07 },
    ].freeze

    NOMBRES   = %w[Ana Bruno Carla Diego Elena Facundo Gabriela Hernán Irina Joaquín Karina Lucas
                   Malena Nicolás Olivia Pablo Rocío Santiago Tamara Valentín].freeze
    APELLIDOS = %w[Álvarez Benítez Cabrera Domínguez Escobar Ferreyra Gómez Herrera Ibáñez Juárez
                   Kaufman Lombardi Medina Navarro Ortiz Peralta Quiroga Ramírez Sosa Torres].freeze

    def self.call(**kwargs) = new(**kwargs).call

    def initialize(nombre: 'Club Modelo', slug: 'club_modelo', admin_email: nil, admin_password: nil,
                   pacientes: 40, dispensaciones: 200, lotes: 30)
      @nombre    = nombre
      @slug      = slug.downcase.gsub(/[^a-z0-9_]/, '_')
      @admin_email    = admin_email.presence || 'admin@club-modelo.example.com'
      @admin_password = admin_password.presence || SecureRandom.hex(12)
      @n_pacientes      = pacientes
      @n_dispensaciones = dispensaciones
      @n_lotes          = lotes
      @resumen = Hash.new(0)
      # Semilla fija: dos corridas generan el mismo club. Si algo se ve raro en una demo, se puede
      # reproducir exactamente.
      @rng = Random.new(20260804)
    end

    def call
      if Club.unscoped.exists?(slug: @slug)
        raise ArgumentError, "Ya existe una organización con el slug '#{@slug}'. Borralo antes de regenerarlo."
      end

      club = nil
      tenant_previo = ActsAsTenant.current_tenant
      begin
        ActiveRecord::Base.transaction do
          club = crear_club
          ActsAsTenant.current_tenant = club
          @admin = crear_equipo(club)
          crear_estructura(club)
          crear_geneticas(club)
          crear_lotes(club)
          crear_pacientes(club)
          crear_stocks(club)
          crear_dispensaciones(club)
          crear_infraestructura_finanzas(club)
          crear_insumos(club)
          crear_salon(club)
          # Va DESPUÉS de dispensaciones y salón: los egresos se dimensionan contra los
          # ingresos que realmente se generaron, para que el club modelo cierre con ganancia.
          crear_contabilidad(club)
          crear_turnos(club)
          crear_reparto(club)
          crear_tareas(club)
          crear_reservas(club)
          crear_manicura(club)
          crear_jornadas(club)
          crear_setpoints(club)
        end
      ensure
        ActsAsTenant.current_tenant = tenant_previo
      end

      Struct.new(:club, :resumen, :password).new(club, @resumen, @admin_password)
    end

    private

    def hoy = Date.current

    def crear_club
      ActsAsTenant.without_tenant do
        Club.create!(
          name: @nombre, slug: @slug, demo: true,
          legal_name: "#{@nombre} Asociación Civil",
          email: 'contacto@club-modelo.example.com', phone: '+54 11 4000-0000',
          city: 'Ciudad Autónoma de Buenos Aires', state: 'CABA', country: 'Argentina',
          timezone: 'America/Argentina/Buenos_Aires',
          plan: 'arbol', plan_trial: false,
          # TODAS las features prendidas: es una vidriera, tiene que poder mostrarse entero.
          features: Club::AVAILABLE_FEATURES.index_with(true),
          web_activa: true,
        )
      end
    end

    # Un usuario por rol: es lo que deja mostrar que la app se ve distinta según quién entra.
    def crear_equipo(club)
      admin = nil
      # Los roles OPERATIVOS: los que se muestran trabajando. Si falta uno, ese módulo no se puede
      # enseñar y quien intenta entrar recibe "credenciales inválidas" sin saber por qué.
      # Abogado y auditor quedan afuera a propósito: son de consulta, no hacen a la demo.
      { 'admin' => 'Admin', 'cultivador' => 'Cultivo', 'dispensador' => 'Dispensa',
        'supervisor' => 'Supervisión', 'medico' => 'Médico', 'manicura' => 'Manicura',
        'delivery' => 'Reparto' }.each do |rol, nom|
        u = User.create!(
          email: rol == 'admin' ? @admin_email : "#{rol}@club-modelo.example.com",
          password: @admin_password, password_confirmation: @admin_password,
          role: rol, club: club, first_name: nom, last_name: 'Demo',
        )
        admin = u if rol == 'admin'
        @resumen[:usuarios] += 1
      end
      admin
    end

    def crear_estructura(club)
      # MIXTA: produce y además tiene salón. Es lo que habilita el módulo de bar/eventos, que sin
      # una sede social no se puede mostrar.
      @sede = Sede.create!(club: club, nombre: 'Sede Central', direccion: 'Av. Siempreviva 742',
                           ciudad: 'CABA', tipo: 'mixta', created_by: @admin)
      # Una segunda sede, solo de producción: sin dos, el selector de sede y el desglose por sede
      # del dashboard no tienen nada que mostrar.
      @sede2 = Sede.create!(club: club, nombre: 'Finca Norte', direccion: 'Ruta 8 km 42',
                            ciudad: 'Pilar', tipo: 'produccion', created_by: @admin)
      @resumen[:sedes] += 2

      @salas = {
        vegetativo: Sala.create!(club: club, sede: @sede, nombre: 'Vegetativo', kind: 'vegetativo',
                                 created_by: @admin, plants_max: 120),
        floracion:  Sala.create!(club: club, sede: @sede, nombre: 'Floración A', kind: 'floracion',
                                 created_by: @admin, plants_max: 80),
        floracion2: Sala.create!(club: club, sede: @sede, nombre: 'Floración B', kind: 'floracion',
                                 created_by: @admin, plants_max: 80),
        madre:      Sala.create!(club: club, sede: @sede, nombre: 'Madres', kind: 'madre',
                                 created_by: @admin, plants_max: 20),
      }
      @resumen[:salas] += @salas.size
    end

    def crear_geneticas(club)
      @geneticas = GENETICAS.map do |g|
        Genetica.create!(
          club: club, nombre: g[:nombre], thc: g[:thc], cbd: g[:cbd],
          tiempo_floracion: g[:dias_flora], descripcion: "Genética de demostración — #{g[:nombre]}",
        ).tap { @resumen[:geneticas] += 1 }
      end
      @perfil = GENETICAS.each_with_index.to_h { |g, i| [@geneticas[i].id, g] }
    end

    # Lotes repartidos en el tiempo y en las fases: los viejos ya finalizados (con rendimiento real,
    # que es lo que hace que la analítica tenga qué mostrar) y los recientes todavía en curso.
    def crear_lotes(club)
      @lotes_finalizados = []

      @n_lotes.times do |i|
        genetica = @geneticas[i % @geneticas.size]
        perfil   = @perfil[genetica.id]
        # Los primeros son los más viejos: se reparten a lo largo del año.
        dias_atras = ((MESES_HISTORIA * 30.0) * (@n_lotes - i) / @n_lotes).round + @rng.rand(-5..5)
        inicio     = hoy - dias_atras
        plantas    = [12, 16, 20, 24].sample(random: @rng)

        estado, ciclo = fase_para(dias_atras, perfil)
        lote = Lote.new(
          club: club, sala: sala_para(estado), sede: @sede, genetica: genetica,
          estado: estado, origen: i.even? ? 'esqueje' : 'semilla',
          start_date: inicio, plants_count: plantas,
          tamanio_maceta: estado == 'enraizado' ? nil : 7,
          tamanio_maceta_inicial: estado == 'enraizado' ? nil : 0.335,
          dias_floracion_objetivo: perfil[:dias_flora],
          grow_type: 'sustrato', light_type: 'led',
        )
        lote.save!(validate: false)

        crear_historia_lote(club, lote, ciclo, perfil, plantas)
        @resumen[:lotes] += 1
      end
    end

    # A qué fase llegó un lote según cuánto hace que arrancó. Devuelve también las fechas de cada
    # transición, que son las que hacen que los informes de ciclos tengan datos reales.
    def fase_para(dias_atras, perfil)
      enraizado  = 14
      vegetativo = enraizado + 28
      floracion  = vegetativo + perfil[:dias_flora]
      cosecha    = floracion + 12   # secado
      manicura   = cosecha + 10

      ciclo = { enraizado: enraizado, vegetativo: vegetativo, floracion: floracion,
                cosecha: cosecha, manicura: manicura }

      estado = if    dias_atras < enraizado  then 'enraizado'
               elsif dias_atras < vegetativo then 'vegetativo'
               elsif dias_atras < floracion  then 'floracion'
               elsif dias_atras < cosecha    then 'cosecha'
               elsif dias_atras < manicura   then 'en_manicura'
               elsif dias_atras < manicura + 60 then 'curado'
               else 'finalizado'
               end
      [estado, ciclo]
    end

    def sala_para(estado)
      case estado
      when 'enraizado', 'vegetativo' then @salas[:vegetativo]
      when 'floracion'               then [@salas[:floracion], @salas[:floracion2]].sample(random: @rng)
      end   # post-cosecha: sin sala
    end

    def crear_historia_lote(club, lote, ciclo, perfil, plantas)
      orden = %w[enraizado vegetativo floracion cosecha en_manicura curado finalizado]
      indice_actual = orden.index(lote.estado)
      inicio = lote.start_date

      # Evento de arranque + una transición por cada fase que el lote ya dejó atrás. Sin estos
      # eventos, los días por fase de los informes salen todos del fallback y no dicen nada.
      LoteEvento.new(tipo: 'cambio_estado', estado_nuevo: 'enraizado', descripcion: 'Inicio',
                     lote: lote, club: club, user: @admin,
                     registrado_en: inicio.in_time_zone.change(hour: 10)).save!(validate: false)

      fechas = { 'vegetativo' => ciclo[:enraizado], 'floracion' => ciclo[:vegetativo],
                 'cosecha' => ciclo[:floracion], 'en_manicura' => ciclo[:cosecha],
                 'curado' => ciclo[:manicura], 'finalizado' => ciclo[:manicura] + 60 }
      orden[1..indice_actual].to_a.each do |fase|
        LoteEvento.new(tipo: 'cambio_estado', estado_anterior: orden[orden.index(fase) - 1],
                       estado_nuevo: fase, descripcion: "Avance a #{fase}",
                       lote: lote, club: club, user: @admin,
                       registrado_en: (inicio + fechas[fase]).in_time_zone.change(hour: 11))
                  .save!(validate: false)
        @resumen[:eventos] += 1
      end

      crear_plantas(club, lote, perfil, plantas)
      crear_registros_ambientales(club, lote)
      cerrar_produccion(lote, perfil, plantas) if %w[curado finalizado].include?(lote.estado)
    end

    def crear_plantas(club, lote, perfil, plantas)
      state = Lote::FASE_A_PLANT_STATE[lote.estado] || 'cosechado'
      # Una parte se pierde: sin descartes, el informe de pérdidas sale vacío y el % de prendimiento
      # da 100% siempre.
      perdidas = (plantas * perfil[:merma]).round
      plantas.times do |i|
        descartada = i < perdidas
        Plant.new(
          club: club, lote: lote, nombre: "#{lote.codigo}-P#{(i + 1).to_s.rjust(3, '0')}",
          state: descartada ? 'descartada' : state,
          motivo_descarte: descartada ? %w[no_prendio plaga macho].sample(random: @rng) : nil,
        ).save!(validate: false)
        @resumen[:plantas] += 1
      end
    end

    # Un registro por semana mientras el lote estuvo en cultivo: es lo que dibuja las curvas de
    # ambiente y lo que evita que salten alertas de "sin registro" por todos lados.
    def crear_registros_ambientales(club, lote)
      desde = lote.start_date
      hasta = [hoy, desde + 120].min
      (desde..hasta).step(7) do |fecha|
        RegistroAmbiental.new(
          club: club, lote: lote, user: @admin, registrado_en: fecha.in_time_zone.change(hour: 9),
          temperatura: 22 + @rng.rand(-2.0..3.0).round(1),
          humedad:     58 + @rng.rand(-8..8),
          ph:          6.0 + @rng.rand(-0.3..0.3).round(2),
          ec:          1.2 + @rng.rand(-0.4..0.6).round(2),
          fuente: 'manual', estado_general: %w[excelente bueno bueno regular].sample(random: @rng),
        ).save!(validate: false)
        @resumen[:registros_ambientales] += 1
      end
    end

    # El rendimiento real es lo que alimenta TODA la analítica de producción. Se calcula desde el
    # perfil de la genética con una variación chica, así una cepa rinde consistentemente mejor que
    # otra —que es justo lo que se quiere mostrar— en vez de ser ruido.
    def cerrar_produccion(lote, perfil, plantas)
      vivas = plantas - (plantas * perfil[:merma]).round
      gramos = (vivas * perfil[:rinde] * @rng.rand(0.85..1.15)).round(1)
      lote.update_columns(rendimiento_real_g: gramos, plants_count_cosechadas: vivas)
      @lotes_finalizados << [lote, gramos]
    end


    # Áreas, categorías contables y depósitos por sede. Se reusan los servicios de siembra del
    # producto en vez de inventar datos: así el club demo queda igual que uno recién creado.
    def crear_infraestructura_finanzas(club)
      Finanzas::SembrarCatalogo.new(club).call(con_arbol: true)
      Finanzas::SembrarDepositos.new(club).call
      Bar::SembrarCategoriasProducto.new(club).call if defined?(Bar::SembrarCategoriasProducto)
      @resumen[:depositos] += Deposito.where(club_id: club.id).count
    end

    INSUMOS = [
      ['Sustrato coco 50L',      'bolsa',    'cultivo', 12_000, 40],
      ['Perlita 100L',           'bolsa',    'cultivo',  9_500, 15],
      ['Fertilizante base A 5L', 'litro',    'cultivo', 28_000, 24],
      ['Fertilizante base B 5L', 'litro',    'cultivo', 28_000, 22],
      ['Corrector de pH 1L',     'litro',    'cultivo',  8_900, 10],
      ['Maceta 7L',              'unidad',   'cultivo',    900, 300],
      ['Guantes de nitrilo',     'unidad',   'general',    350, 500],
      ['Bolsas de curado 1kg',   'unidad',   'general',  1_800, 120],
      ['Etiquetas QR',           'unidad',   'general',    120, 1_000],
    ].freeze

    def crear_insumos(club)
      deposito = Deposito.where(club_id: club.id, sede_id: @sede.id).first
      INSUMOS.each do |nombre, unidad, tipo, costo, stock|
        Insumo.create!(
          club: club, sede: @sede, deposito: deposito, nombre: nombre,
          unidad_medida: unidad, tipo: tipo,
          costo_promedio_ars: costo, stock_actual: stock,
          stock_minimo: (stock * 0.2).round,
        )
        @resumen[:insumos] += 1
      end
    end

    PRODUCTOS_BAR = [
      ['Café',                 'bebida',  2_500, 60],
      ['Agua saborizada 500ml','bebida',  2_000, 80],
      ['Cerveza artesanal',    'bebida',  5_500, 45],
      ['Sándwich veggie',      'cocina',  7_800, 20],
      ['Brownie',              'cocina',  4_200, 25],
      ['Papas rústicas',       'cocina',  6_000, 30],
      ['Remera del club',      'merch',  22_000, 15],
      ['Gorra',                'merch',  16_000, 12],
      ['Encendedor',           'otro',    1_500, 90],
    ].freeze

    # El salón: la barra, su mercadería y un año de ventas. Sin esto el módulo se ve vacío, que es
    # justo lo que no se quiere mostrar.
    def crear_salon(club)
      bar = Barra.create!(club: club, sede: @sede, nombre: 'Salón Central', activo: true)
      @resumen[:bares] += 1

      unidad   = UnidadNegocio.where(club_id: club.id, tipo: 'bar').first
      deposito = Deposito.where(club_id: club.id, sede_id: @sede.id, clave_sistema: 'salon').first

      productos = PRODUCTOS_BAR.map do |nombre, categoria, precio, stock|
        BarProducto.create!(
          club: club, bar: bar, nombre: nombre, categoria: categoria,
          precio_ars: precio, stock: stock, stock_minimo: 5,
          unidad_negocio: unidad, deposito: deposito, vendible: true,
        ).tap { @resumen[:productos_bar] += 1 }
      end

      vendedor = User.where(club_id: club.id, role: 'dispensador').first || @admin
      # Mismo criterio que las dispensaciones: las ventas siguen una curva, no son parejas.
      12.times do |idx|
        mes = hoy - (MESES_HISTORIA - 1 - idx).months
        (8 + idx * 2).times do
          fecha = mes.beginning_of_month + @rng.rand(0..27)
          next if fecha > hoy

          elegidos = productos.sample(@rng.rand(1..3), random: @rng)
          total = 0
          venta = BarVenta.new(
            club: club, bar: bar, user: vendedor, unidad_negocio: unidad,
            medio_pago: %w[efectivo transferencia mercado_pago].sample(random: @rng),
            total_ars: 0,
          )
          venta.save!(validate: false)
          # BarVenta no tiene columna de fecha: se ubica en el tiempo por created_at, así que hay
          # que backdatearlo para que el histórico del salón tenga un año de movimiento.
          BarVenta.unscoped.where(id: venta.id)
                  .update_all(created_at: fecha.in_time_zone.change(hour: @rng.rand(11..22)))
          elegidos.each do |prod|
            cant = @rng.rand(1..3)
            sub  = prod.precio_ars.to_d * cant
            total += sub
            BarVentaItem.new(
              club: club, bar_venta: venta, bar_producto: prod, vendible: prod,
              nombre: prod.nombre, cantidad: cant,
              precio_unitario_ars: prod.precio_ars, subtotal_ars: sub,
            ).save!(validate: false)
          end
          venta.update_columns(total_ars: total)

          # El ingreso contable: sin esto el salón vendía todo el año y no aportaba un peso al
          # P&L —el club modelo cerraba en pérdida—. Se backdatea a la fecha de la venta.
          begin
            mov = venta.reload.crear_ingreso!
            mov.update_columns(fecha: fecha)
          rescue => e
            Rails.logger.warn "[SembrarDemo] asiento de venta del salón: #{e.message}"
          end
          @resumen[:ventas_bar] += 1
        end
      end
    end

    # Reparto: una parte de las dispensaciones sale con envío asignado al repartidor. Sin esto su
    # PWA arranca vacía y no se puede mostrar ni la ruta ni el historial.
    def crear_reparto(club)
      repartidor = User.where(club_id: club.id, role: 'delivery').first
      return unless repartidor

      disps = Dispensacion.joins(:paciente).where(pacientes: { club_id: club.id })
                          .order(fecha_dispensacion: :desc).limit(28).to_a
      disps.each_with_index do |d, i|
        # Las más recientes quedan por despachar; las viejas, cerradas.
        estado = if    i < 5  then 'pendiente'
                 elsif i < 8  then 'en_viaje'
                 elsif i < 25 then 'entregado'
                 else              'fallido'
                 end
        d.update_columns(
          con_envio: true, delivery_id: repartidor.id, estado_envio: estado,
          direccion_envio: "#{%w[Av. Rivadavia Corrientes Cabildo Scalabrini\ Ortiz].sample(random: @rng)} #{@rng.rand(100..8000)}",
          entregado_at: estado == 'entregado' ? d.fecha_dispensacion.in_time_zone.change(hour: 18) : nil,
          motivo_fallo: estado == 'fallido' ? ['Nadie en el domicilio', 'Dirección inexistente'].sample(random: @rng) : nil,
        )
        @resumen[:envios] += 1
      end
    end


    TAREAS_TIPO = {
      'riego'           => 'Riego de la sala',
      'nutricion'       => 'Nutrición semanal',
      'revision_plagas' => 'Revisión de plagas',
      'poda'            => 'Poda de bajos',
      'limpieza'        => 'Limpieza del cuarto',
      'medicion'        => 'Medición de pH y EC',
      'defoliacion'     => 'Defoliación',
      'trasplante'      => 'Trasplante a maceta final',
    }.freeze

    # Sin tareas, la tab del cultivador y el "tareas hoy" del admin salen en cero — dos de las
    # primeras pantallas que ve alguien a quien se le muestra la app.
    def crear_tareas(club)
      cultivador = User.where(club_id: club.id, role: 'cultivador').first || @admin
      salas = Sala.where(club_id: club.id).to_a
      lotes = Lote.where(club_id: club.id, estado: %w[vegetativo floracion]).to_a
      return if salas.empty?

      45.times do |i|
        tipo, titulo = TAREAS_TIPO.to_a.sample(random: @rng)
        # Un tercio vencidas o de hoy (lo que hay que hacer AHORA), el resto repartido: una lista
        # solo de futuro no muestra que la app sirve para no olvidarse nada.
        dias = case i % 3
               when 0 then -@rng.rand(0..4)
               when 1 then 0
               else        @rng.rand(1..12)
               end
        completada = dias < 0 && @rng.rand < 0.6
        Tarea.create!(
          club: club, creada_por: @admin, asignada_a: cultivador,
          sala: salas.sample(random: @rng), lote: lotes.sample(random: @rng),
          titulo: titulo, tipo: tipo,
          estado: completada ? 'completada' : 'pendiente',
          prioridad: %w[baja normal normal alta].sample(random: @rng),
          fecha_programada: hoy + dias,
        )
        @resumen[:tareas] += 1
      end
    end

    # Reservas: es la tab entera del dispensador. Vacía, no se puede mostrar para qué sirve apartar
    # stock a futuro.
    def crear_reservas(club)
      dispensador = User.where(club_id: club.id, role: 'dispensador').first || @admin
      return if @stocks.empty? || @pacientes.empty?

      # Releídos de la base: los de @stocks quedaron desactualizados cuando las 176 dispensaciones
      # les descontaron cantidad. Y se filtra por lo REALMENTE disponible —la reserva aparta, y el
      # modelo no deja prometer algo que el club no tiene—.
      disponibles = Stock.where(club_id: club.id)
                         .select { |st| st.cantidad_disponible_real.to_d >= 40 }
      return if disponibles.empty?

      12.times do |i|
        stock  = disponibles.sample(random: @rng)
        precio = stock.precio_sugerido_ars.to_d
        cant   = [5, 10, 15].sample(random: @rng)
        total  = (precio * cant).round(2)
        sena = i.even? ? (total * 0.5).round(2) : total
        r = Reserva.new(
          club: club, paciente: @pacientes.sample(random: @rng), stock: stock, user: dispensador,
          cantidad: cant, fecha_entrega_estimada: hoy + @rng.rand(1..10), estado: 'pendiente',
          sena_ars: sena, aporte_estimado_ars: total, medio_pago: 'efectivo',
        )
        r.save!
        # Algunas VENCIDAS: el aviso de "esto quedó de ayer" es justo lo que hay que poder mostrar.
        # Se retrasa después de crear porque el modelo exige fecha futura al dar de alta —una
        # reserva para hoy ya es una dispensación— y esa regla no se saltea, se respeta y se
        # envejece el registro, que es lo que pasa en la vida real.
        r.update_column(:fecha_entrega_estimada, hoy - @rng.rand(1..5)) if i < 3
        @resumen[:reservas] += 1
      end
    end

    # Manicura: sin pesajes, ese rol entra y no tiene absolutamente nada que ver.
    def crear_manicura(club)
      manicura = User.where(club_id: club.id, role: 'manicura').first || @admin
      lotes    = Lote.where(club_id: club.id, estado: %w[en_manicura curado finalizado]).limit(8).to_a
      return if lotes.empty?

      lotes.each_with_index do |lote, i|
        # Los dos primeros quedan ENVIADOS a propósito: son los que le dan trabajo a la tab
        # "Aprobar" del admin. Si todos salen confirmados, esa pantalla se ve vacía.
        confirmado = i >= 2 && lote.estado != 'en_manicura'
        PesajeManicura.create!(
          club: club, lote: lote, manicurador: manicura,
          fecha_pesaje: hoy - @rng.rand(1..90),
          estado: confirmado ? 'confirmado' : %w[borrador enviado].sample(random: @rng),
          peso_total_g: (lote.rendimiento_real_g || @rng.rand(400..1400)).to_d,
          peso_confirmado_g: confirmado ? (lote.rendimiento_real_g || @rng.rand(400..1400)).to_d : nil,
          confirmado_por: confirmado ? @admin : nil,
          plantas_count: lote.plants_count,
        )
        @resumen[:pesajes_manicura] += 1
      end
    end

    # "Mis horas" del cultivador y de manicura.
    def crear_jornadas(club)
      User.where(club_id: club.id, role: %w[cultivador manicura]).each do |u|
        20.times do |i|
          fecha = hoy - i
          next if fecha.saturday? || fecha.sunday?
          JornadaLaboral.create!(
            club: club, user: u, fecha: fecha,
            hora_entrada: '09:00', hora_salida: %w[17:00 17:30 18:00].sample(random: @rng),
            estado: i < 3 ? 'enviada' : 'confirmada',
            confirmada_por: i < 3 ? nil : @admin,
          )
          @resumen[:jornadas] += 1
        end
      end
    end

    # Los rangos de ambiente por fase: es lo que hace que las alertas y el semáforo tengan contra
    # qué comparar. Sin esto el módulo de IoT se ve sin configurar.
    SETPOINTS = {
      'enraizado'  => { 'temperatura' => [22, 26], 'humedad' => [85, 95], 'ph' => [5.5, 6.0] },
      'vegetativo' => { 'temperatura' => [20, 28], 'humedad' => [50, 70], 'ph' => [5.8, 6.2], 'ec' => [0.8, 1.4] },
      'floracion'  => { 'temperatura' => [20, 26], 'humedad' => [40, 55], 'ph' => [6.0, 6.5], 'ec' => [1.4, 2.2] },
    }.freeze

    def crear_setpoints(club)
      SETPOINTS.each do |fase, tipos|
        tipos.each do |tipo, (min, max)|
          SetpointFase.create!(club_id: club.id, fase: fase, tipo_lectura: tipo,
                               valor_min: min, valor_max: max)
          @resumen[:setpoints] += 1
        end
      end
    end

    # Turnos médicos repartidos entre pasados (realizados) y próximos: la agenda vacía no muestra
    # nada, y una llena solo de futuros no deja ver el historial clínico.
    def crear_turnos(club)
      medico = User.where(club_id: club.id, role: 'medico').first || @admin
      40.times do |i|
        paciente = @pacientes[i % @pacientes.size]
        pasado   = i < 28
        fecha    = pasado ? hoy - @rng.rand(1..180) : hoy + @rng.rand(1..25)
        estado   = if !pasado then %w[programado confirmado].sample(random: @rng)
                   else %w[realizado realizado realizado cancelado ausente].sample(random: @rng)
                   end
        Turno.create!(
          club: club, paciente: paciente, medico: medico,
          fecha_hora: fecha.in_time_zone.change(hour: @rng.rand(9..18)),
          duracion_minutos: 30, tipo: TIPOS_TURNO.sample(random: @rng), estado: estado,
        )
        @resumen[:turnos] += 1
      end
    end

    TIPOS_TURNO = %w[primera_vez seguimiento seguimiento revision].freeze

    def crear_pacientes(club)
      @pacientes = @n_pacientes.times.map do |i|
        # REPROCANN en los tres estados: sin vencimientos próximos, los informes de cumplimiento y
        # el panel de "críticos" salen vacíos, que es justo lo que hay que poder mostrar.
        estado, vence = case i % 10
                        when 0, 1 then ['vencido',  hoy - @rng.rand(5..60)]
                        when 2, 3 then ['activo',   hoy + @rng.rand(5..30)]   # por vencer
                        else           ['activo',   hoy + @rng.rand(60..300)]
                        end
        Paciente.create!(
          club: club, created_by: @admin,
          # El apellido rota con una vuelta extra cada ciclo de nombres: con `i * 7` a secas, el
          # paciente 0 y el 20 caían en la MISMA combinación y la lista parecía tener duplicados.
          nombre:   NOMBRES[i % NOMBRES.size],
          apellido: APELLIDOS[((i * 7) + (i / NOMBRES.size)) % APELLIDOS.size],
          dni: (20_000_000 + i * 137_411).to_s,
          fecha_nacimiento: hoy - @rng.rand(21..65).years - @rng.rand(0..364).days,
          # example.com es un dominio reservado: ningún mailer que se dispare le escribe a una
          # persona real.
          email: "paciente#{i + 1}@example.com",
          telefono: "+54 11 5#{format('%03d', i)}-#{format('%04d', i * 13 % 10_000)}",
          reprocann_estado: estado, reprocann_vencimiento: vence,
          reprocann_numero: "RC-#{100_000 + i}",
        ).tap { @resumen[:pacientes] += 1 }
      end
    end

    def crear_stocks(club)
      @stocks = @lotes_finalizados.map do |lote, gramos|
        perfil = @perfil[lote.genetica_id]
        # Parte ya dispensada: un stock intacto no muestra movimiento.
        restante = (gramos * @rng.rand(0.15..0.8)).round(1)
        stock = Stock.new(
          club: club, sede: @sede, lote: lote, genetica: lote.genetica,
          origen: 'lote', forma_producto: 'flor_seca', unidad: 'g',
          cantidad: restante, estado: restante.positive? ? 'asignado' : 'agotado',
          disponibilidad: 'dispensa',
          costo_unitario_ars: (1_200 * @rng.rand(0.9..1.1)).round(2),
          precio_sugerido_ars: (perfil[:cbd] > 5 ? 3_800 : 3_200) * @rng.rand(0.95..1.1),
          descripcion: "#{lote.genetica.nombre} — #{lote.codigo}",
        ).tap { |s| s.save!(validate: false); @resumen[:stocks] += 1 }

        reconciliar_estado_con_stock(lote, restante)
        stock
      end.select { |s| s.cantidad.to_d.positive? }
    end

    # El estado del lote se elegía sólo por antigüedad (`fase_para`), y el gramaje que le queda
    # se sortea acá: un lote viejo salía 'finalizado' y a renglón seguido recibía 485 g de flor.
    # El informe de trazabilidad lo mostraba como ciclo cerrado con producto adentro.
    #
    # 'finalizado' significa que no queda nada: si al lote le sobró stock, el estado que
    # corresponde es 'curado' (en frasco, dispensándose). Se corrige acá —y no en `fase_para`—
    # porque recién en este punto se sabe cuánto quedó.
    def reconciliar_estado_con_stock(lote, restante)
      return unless lote.estado == 'finalizado' && restante.to_d.positive?

      lote.update_columns(estado: 'curado')
      # El evento del avance también sobra: la línea de tiempo diría que cerró un ciclo que
      # sigue abierto, y de ahí salen los días por fase de los informes.
      LoteEvento.where(lote_id: lote.id, tipo: 'cambio_estado', estado_nuevo: 'finalizado')
                .delete_all
    end

    # Dispensaciones repartidas a lo largo del año, con una CURVA: arranca flojo, cae en invierno y
    # se recupera fuerte. Un volumen parejo da un gráfico plano que no cuenta nada.
    def crear_dispensaciones(club)
      return if @stocks.empty? || @pacientes.empty?

      dispensador = User.where(club_id: club.id, role: 'dispensador').first || @admin
      peso_mes = [0.5, 0.6, 0.7, 0.8, 0.6, 0.4, 0.4, 0.6, 0.9, 1.1, 1.3, 1.5]   # de hace 12 meses a hoy
      total_peso = peso_mes.sum

      peso_mes.each_with_index do |peso, idx|
        cuantas = (@n_dispensaciones * peso / total_peso).round
        mes_base = hoy - (MESES_HISTORIA - 1 - idx).months

        cuantas.times do
          stock    = @stocks.sample(random: @rng)
          paciente = @pacientes.sample(random: @rng)
          cantidad = [5, 10, 10, 15, 20, 30].sample(random: @rng)
          fecha    = mes_base.beginning_of_month + @rng.rand(0..27)
          next if fecha > hoy

          medio  = %w[efectivo efectivo transferencia cuenta_corriente no_abona].sample(random: @rng)
          precio = stock.precio_sugerido_ars.to_d
          total  = (precio * cantidad).round(2)
          # Dispensacion NO tiene club_id: el tenant se resuelve por el paciente.
          disp = Dispensacion.new(
            paciente: paciente, user: dispensador, stock: stock, sede: @sede,
            cantidad: cantidad, fecha_dispensacion: fecha, medio_pago: medio,
            precio_unitario_ars: precio,
            # `aporte_socio_ars` es lo que COBRA la dispensa: sin esto el asiento contable sale en
            # cero y la contabilidad del club demo mostraba solo egresos.
            aporte_socio_ars: total,
            monto_credito_ars: %w[cuenta_corriente no_abona].include?(medio) ? total : 0,
          )
          disp.save!(validate: false)
          DispensacionItem.new(dispensacion: disp, stock: stock, cantidad: cantidad,
                               precio_unitario_ars: precio).save!(validate: false)

          # El asiento contable lo crea este service, no un callback del modelo: guardando con
          # `validate: false` no corre nada, así que hay que invocarlo. Es el MISMO camino que usa
          # la app al dispensar, así que los datos del demo salen como los reales.
          begin
            Dispensaciones::AplicarEfectos.financiero!(dispensacion: disp, usuario: dispensador)
          rescue => e
            Rails.logger.warn "[SembrarDemo] asiento de dispensación: #{e.message}"
          end
          @resumen[:dispensaciones] += 1
        end
      end
    end

    # Un club que opera bien CIERRA EN GANANCIA. Los egresos del demo estaban clavados en
    # rangos fijos (~1M por mes) contra ingresos que dependían del azar de las dispensaciones:
    # el resultado daba pérdida, que es justo lo que un club modelo no tiene que mostrar.
    #
    # Ahora se dimensionan CONTRA los ingresos reales de cada mes, dejando este margen. 32% es
    # bueno y creíble para un club que produce lo que vende: no paga la flor, la cultiva.
    MARGEN_OBJETIVO = 0.32

    # Reparto del gasto operativo. Suma 1.0.
    REPARTO_EGRESOS = [
      ['sueldo',        0.46],
      ['insumo',        0.24],
      ['electricidad',  0.18],
      ['alquiler',      0.12],
    ].freeze

    def crear_contabilidad(club)
      lotes = Lote.where(club_id: club.id).to_a

      MESES_HISTORIA.times do |i|
        mes   = (hoy - (MESES_HISTORIA - 1 - i).months).beginning_of_month
        fecha = [mes + 5, hoy].min
        next if mes > hoy

        # El scope `ingresos` del modelo, no `tipo: 'ingreso'`: las dispensaciones asientan como
        # `recupero_costo` —recuperan el costo de producir— y son el grueso de lo que entra.
        # Contando solo 'ingreso' se dimensionaban los egresos contra el buffet nada más.
        ingresos = club.movimientos_contables
                       .ingresos
                       .where(fecha: mes..mes.end_of_month)
                       .sum(:monto_ars).to_d
        # Los primeros meses del histórico pueden no tener ventas todavía: ahí se usa un piso
        # para que el mes no quede sin gastos y el P&L se vea plano.
        base = ingresos.positive? ? ingresos * (1 - MARGEN_OBJETIVO) : 350_000.to_d

        REPARTO_EGRESOS.each do |categoria, peso|
          # ±8% para que los meses no salgan calcados y el gráfico tenga vida.
          monto = (base * peso * (0.92 + @rng.rand * 0.16)).round(-2)
          next if monto <= 0

          MovimientoContable.new(
            club: club, created_by: @admin, sede: @sede,
            tipo: 'egreso', categoria: categoria, monto_ars: monto,
            fecha: fecha, descripcion: "#{categoria.capitalize} — #{fecha.strftime('%m/%Y')}",
            # Los de insumo van imputados a un lote: sin eso, costo/gramo por lote queda vacío.
            lote: categoria == 'insumo' ? lotes.sample(random: @rng) : nil,
          ).save!(validate: false)
          @resumen[:movimientos_contables] += 1
        end
      end
    end
  end
end
