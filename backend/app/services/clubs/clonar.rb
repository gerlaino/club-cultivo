module Clubs
  # Copia el CULTIVO de una organización a una organización nueva: sedes, salas, genéticas, lotes con sus plantas y
  # toda su historia. Sirve para tener una organización de prueba con datos reales de cultivo sin arrastrar
  # lo comercial, lo contable ni lo médico.
  #
  # QUÉ NO SE COPIA, a propósito: tareas, auditorías, alertas (se regeneran solas), contabilidad,
  # depósitos, pacientes y cuentas corrientes, dispensaciones, reservas, bar, insumos, jornadas,
  # turnos y mails. Nada de eso hace falta para ver funcionar el cultivo, y los pacientes además son
  # datos personales que no tienen por qué viajar a una organización de prueba.
  #
  # TRES CAMPOS SON ÚNICOS A NIVEL BASE, no por club, así que se REGENERAN en el destino:
  # `lotes.codigo_qr`, `lotes.codigo_qr_cosecha`, `plants.codigo_qr` y `stocks.codigo_qr`. Copiarlos
  # tal cual revienta contra el índice único.
  #
  # LOS USUARIOS NO SE COPIAN: `users.email` es único global. Se crea un admin en la organización destino y
  # todo lo que apuntaba a una persona (eventos, registros, pesajes) queda a su nombre.
  class Clonar
    Result = Struct.new(:club, :resumen, keyword_init: true)

    def self.call(**kwargs) = new(**kwargs).call

    def initialize(origen:, nombre:, slug: nil, admin_email: nil, admin_password: nil)
      @origen = origen
      @nombre = nombre
      # `Club#slug` solo admite [a-z0-9_]: parameterize devuelve guiones y la validación lo rechaza.
      @slug = (slug.presence || nombre.parameterize(separator: '_')).downcase.gsub(/[^a-z0-9_]/, '_')
      # example.com es un dominio reservado: nada de lo que se mande ahí sale a la calle.
      @admin_email = admin_email.presence || "admin@#{@slug.tr('_', '-')}.example.com"
      @admin_password = admin_password.presence || SecureRandom.hex(12)
      @map            = Hash.new { |h, k| h[k] = {} }   # {:lotes => {viejo_id => nuevo_id}}
      @resumen        = Hash.new(0)
    end

    def call
      if Club.unscoped.exists?(slug: @slug)
        raise ArgumentError, "Ya existe una organización con el slug '#{@slug}'. Elegí otro o borrá el anterior."
      end

      datos = leer_origen

      club = nil
      tenant_previo = ActsAsTenant.current_tenant
      begin
        ActiveRecord::Base.transaction do
          club = crear_club
          # El tenant se fija a mano, sin bloque, para que siga puesto cuando corran los
          # `after_commit` al cerrar la transacción: el de Lote consulta la genética y con
          # `require_tenant` explotaría. Se restaura en el ensure.
          ActsAsTenant.current_tenant = club
          @admin = crear_admin(club)
          copiar_sedes(club, datos)
          copiar_salas(club, datos)
          copiar_geneticas(club, datos)
          copiar_lotes(club, datos)
          copiar_plants(club, datos)
          reconectar_plantas_madre(datos)
          copiar_lote_eventos(club, datos)
          copiar_plant_activities(datos)
          copiar_registros_ambientales(club, datos)
          copiar_lecturas_ambientales(club, datos)
          copiar_pesadas(datos)
          copiar_pesajes_manicura(club, datos)
          copiar_stocks(club, datos)
        end
      ensure
        ActsAsTenant.current_tenant = tenant_previo
      end

      Result.new(club: club, resumen: @resumen)
    end

    private

    # Se lee TODO antes de escribir: una vez fijado el tenant destino, las queries devolverían los
    # registros de la organización nueva y no habría de dónde copiar.
    def leer_origen
      ActsAsTenant.without_tenant do
        id = @origen.id
        lotes  = Lote.unscoped.where(club_id: id).to_a
        plants = Plant.unscoped.where(lote_id: lotes.map(&:id)).to_a
        {
          sedes:      Sede.unscoped.where(club_id: id).to_a,
          salas:      Sala.unscoped.where(club_id: id).to_a,
          geneticas:  Genetica.unscoped.where(club_id: id).to_a,
          lotes:      lotes,
          plants:     plants,
          eventos:    LoteEvento.unscoped.where(lote_id: lotes.map(&:id)).to_a,
          activities: PlantActivity.unscoped.where(plant_id: plants.map(&:id)).to_a,
          registros:  RegistroAmbiental.unscoped.where(lote_id: lotes.map(&:id)).to_a,
          lecturas:   LecturaAmbiental.unscoped.where(club_id: id).to_a,
          pesadas:    Pesada.unscoped.where(lote_id: lotes.map(&:id)).to_a,
          pesajes:    PesajeManicura.unscoped.where(lote_id: lotes.map(&:id)).to_a,
          stocks:     Stock.unscoped.where(club_id: id).to_a,
        }
      end
    end

    def crear_club
      attrs = @origen.attributes.except('id', 'created_at', 'updated_at', 'slug', 'name',
                                        'deleted_at', 'deleted_by_id')
      # Sin tenant: al crear una organización corre `crear_geneticas_default!`, que consulta las genéticas
      # GLOBALES (club_id nil). Con un tenant fijado esa query no las vería, y sin ninguno explota
      # por `require_tenant`.
      ActsAsTenant.without_tenant { Club.create!(attrs.merge('name' => @nombre, 'slug' => @slug)) }
    end

    def crear_admin(club)
      User.create!(
        email: @admin_email, password: @admin_password, password_confirmation: @admin_password,
        role: 'admin', club: club, first_name: 'Admin', last_name: @nombre,
      ).tap { @resumen[:usuarios] += 1 }
    end

    # `dup` no alcanza: hay que limpiar las claves de la organización viejo y todo lo que apunte a personas
    # que no viajan.
    def clonar_attrs(registro, salvo: [])
      registro.attributes.except('id', 'created_at', 'updated_at', 'deleted_by_id', *salvo)
    end

    # Escribe la fila SIN CALLBACKS ni validaciones, y devuelve el id nuevo.
    #
    # Es la pieza central de este service, y no es una optimización: los callbacks de estos modelos
    # están hechos para datos NUEVOS —propagar una lectura ambiental, generar un QR, disparar un
    # webhook de avance de fase— y acá se está copiando HISTORIA, donde ninguno corresponde. Peor:
    # varios resuelven la organización o la sala a través de una asociación (`lote.sala_id`), y el
    # `default_scope` de Lote/Plant/Sala esconde los soft-deleted, así que para cualquier hijo de un
    # padre borrado la asociación devuelve nil y el callback explota. Un solo lote borrado con
    # plantas tumbaba la copia entera.
    #
    # Las validaciones tampoco aplican: son datos que ya existen y las reglas de hoy no son
    # necesariamente las de cuando se crearon.
    def insertar(modelo, attrs)
      ahora = Time.current
      fila  = attrs.merge('created_at' => ahora, 'updated_at' => ahora)
      # Solo columnas reales: un atributo de más hace fallar el INSERT.
      fila  = fila.slice(*modelo.column_names)
      id    = modelo.insert!(fila, returning: %w[id]).first['id']

      # `insert!` aplica el `default_scope` del modelo COMO VALOR por defecto, así que en los que
      # tienen `default_scope { where(deleted_at: nil) }` (Lote, Plant, Sala, Sede, Genetica) pisa el
      # `deleted_at` con nil y un registro borrado revivía en la copia. Se repone aparte.
      borrado = fila['deleted_at']
      modelo.unscoped.where(id: id).update_all(deleted_at: borrado) if borrado.present?
      id
    end

    def copiar_sedes(club, datos)
      datos[:sedes].each do |s|
        @map[:sedes][s.id] = insertar(Sede, clonar_attrs(s, salvo: %w[club_id created_by_id])
                                              .merge('club_id' => club.id, 'created_by_id' => @admin.id))
        @resumen[:sedes] += 1
      end
    end

    def copiar_salas(club, datos)
      datos[:salas].each do |s|
        @map[:salas][s.id] = insertar(Sala, clonar_attrs(s, salvo: %w[club_id sede_id created_by_id responsable_id])
                                              .merge('club_id' => club.id,
                                                     'sede_id' => @map[:sedes][s.sede_id],
                                                     'created_by_id' => @admin.id,
                                                     'responsable_id' => nil))
        @resumen[:salas] += 1
      end
    end

    def copiar_geneticas(club, datos)
      datos[:geneticas].each do |g|
        @map[:geneticas][g.id] = insertar(Genetica, clonar_attrs(g, salvo: %w[club_id])
                                                      .merge('club_id' => club.id))
        @resumen[:geneticas] += 1
      end
    end

    def copiar_lotes(club, datos)
      datos[:lotes].each do |l|
        attrs = clonar_attrs(l, salvo: %w[club_id sala_id sede_id genetica_id manicurador_id
                                          planta_madre_id lote_origen_id codigo_qr codigo_qr_cosecha])
        nuevo = attrs.merge(
          'club_id'     => club.id,
          'sala_id'     => @map[:salas][l.sala_id],
          'sede_id'     => @map[:sedes][l.sede_id],
          'genetica_id' => @map[:geneticas][l.genetica_id],
          # El manicurador y la planta madre se resuelven aparte (o se sueltan): el primero es una
          # persona que no viaja; la segunda es una planta que todavía no existe en el destino.
          'manicurador_id'  => nil,
          'planta_madre_id' => nil,
          'lote_origen_id'  => nil,
        )
        # Los QR se arman acá: sin callbacks nadie los genera, y son únicos A NIVEL BASE.
        nuevo['codigo_qr'] = "L-#{club.id}-#{Time.now.to_i}-#{SecureRandom.hex(4)}"
        nuevo['codigo_qr_cosecha'] = l.codigo_qr_cosecha.present? ? "C-#{club.id}-#{SecureRandom.hex(6)}" : nil
        @map[:lotes][l.id] = insertar(Lote, nuevo)
        @resumen[:lotes] += 1
      end
      # `lote_origen_id` (desprendimientos) recién se puede resolver con todos los lotes creados.
      datos[:lotes].select(&:lote_origen_id).each do |l|
        Lote.where(id: @map[:lotes][l.id]).update_all(lote_origen_id: @map[:lotes][l.lote_origen_id])
      end
    end

    def copiar_plants(club, datos)
      datos[:plants].each do |p|
        lote_destino = @map[:lotes][p.lote_id]
        next unless lote_destino   # planta de un lote que no viajó: no se copia huérfana

        attrs = clonar_attrs(p, salvo: %w[club_id lote_id codigo_qr qr_token])
                  .merge('club_id' => club.id, 'lote_id' => lote_destino,
                         'codigo_qr' => "#{club.id}-#{lote_destino}-#{Time.now.to_i}-#{SecureRandom.hex(4)}")
        attrs['qr_token'] = nil if Plant.column_names.include?('qr_token')
        @map[:plants][p.id] = insertar(Plant, attrs)
        @resumen[:plantas] += 1
      end
    end

    # Ahora sí: las madres ya existen en el destino.
    def reconectar_plantas_madre(datos)
      datos[:lotes].select(&:planta_madre_id).each do |l|
        destino = @map[:plants][l.planta_madre_id]
        next unless destino
        Lote.where(id: @map[:lotes][l.id]).update_all(planta_madre_id: destino)
      end
    end

    def copiar_lote_eventos(club, datos)
      datos[:eventos].each do |e|
        destino = @map[:lotes][e.lote_id]
        next unless destino
        insertar(LoteEvento, clonar_attrs(e, salvo: %w[club_id lote_id user_id sala_origen_id sala_destino_id])
                               .merge('club_id' => club.id,
                                      'lote_id' => destino,
                                      'user_id' => @admin.id,
                                      'sala_origen_id'  => @map[:salas][e.sala_origen_id],
                                      'sala_destino_id' => @map[:salas][e.sala_destino_id]))
        @resumen[:eventos] += 1
      end
    end

    def copiar_plant_activities(datos)
      datos[:activities].each do |a|
        destino = @map[:plants][a.plant_id]
        next unless destino
        attrs = clonar_attrs(a, salvo: %w[plant_id user_id]).merge('plant_id' => destino)
        attrs['user_id'] = @admin.id if PlantActivity.column_names.include?('user_id')
        insertar(PlantActivity, attrs)
        @resumen[:actividades] += 1
      end
    end

    def copiar_registros_ambientales(club, datos)
      datos[:registros].each do |r|
        destino = @map[:lotes][r.lote_id]
        next unless destino
        # Sin el callback de propagación: las lecturas ambientales se copian aparte, tal cual del
        # origen, con su sala y su fecha. Propagando se regenerarían con la sala de HOY.
        insertar(RegistroAmbiental, clonar_attrs(r, salvo: %w[club_id lote_id user_id])
                                      .merge('club_id' => club.id,
                                             'lote_id' => destino,
                                             'user_id' => @admin.id))
        @resumen[:registros_ambientales] += 1
      end
    end

    def copiar_lecturas_ambientales(club, datos)
      datos[:lecturas].each do |l|
        attrs = clonar_attrs(l, salvo: %w[club_id sala_id lote_id dispositivo_id origen_record_id])
                  .merge('club_id' => club.id,
                         'sala_id' => @map[:salas][l.sala_id],
                         'lote_id' => @map[:lotes][l.lote_id],
                         'dispositivo_id' => nil,
                         # El registro de origen quedó en la organización viejo: se corta el puntero en vez
                         # de apuntar a un id ajeno.
                         'origen_record_id' => nil)
        next unless attrs['sala_id']
        insertar(LecturaAmbiental, attrs)
        @resumen[:lecturas] += 1
      end
    end

    def copiar_pesadas(datos)
      datos[:pesadas].each do |p|
        destino = @map[:lotes][p.lote_id]
        next unless destino
        @map[:pesadas][p.id] = insertar(Pesada, clonar_attrs(p, salvo: %w[lote_id registrado_por_id])
                                                  .merge('lote_id' => destino,
                                                         'registrado_por_id' => @admin.id))
        @resumen[:pesadas] += 1
      end
    end

    def copiar_pesajes_manicura(club, datos)
      datos[:pesajes].each do |p|
        destino = @map[:lotes][p.lote_id]
        next unless destino
        insertar(PesajeManicura, clonar_attrs(p, salvo: %w[club_id lote_id manicurador_id confirmado_por_id])
                                   .merge('club_id' => club.id,
                                          'lote_id' => destino,
                                          'manicurador_id' => @admin.id,
                                          'confirmado_por_id' => @admin.id))
        @resumen[:pesajes_manicura] += 1
      end
    end

    def copiar_stocks(club, datos)
      datos[:stocks].each do |s|
        # `lote_id` puede ser nil de verdad (stock de compra externa); lo que se saltea es el que
        # apuntaba a un lote que no viajó.
        next if s.lote_id.present? && @map[:lotes][s.lote_id].blank?
        attrs = clonar_attrs(s, salvo: %w[club_id lote_id sede_id codigo_qr])
                  .merge('club_id' => club.id,
                         'lote_id' => @map[:lotes][s.lote_id],
                         'sede_id' => @map[:sedes][s.sede_id],
                         'codigo_qr' => "S-#{club.id}-#{Time.now.to_i}-#{SecureRandom.hex(4)}")
        insertar(Stock, attrs)
        @resumen[:stocks] += 1
      end
    end
  end
end
