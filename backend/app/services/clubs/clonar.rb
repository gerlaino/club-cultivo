module Clubs
  # Copia el CULTIVO de un club a un club nuevo: sedes, salas, genéticas, lotes con sus plantas y
  # toda su historia. Sirve para tener un club de prueba con datos reales de cultivo sin arrastrar
  # lo comercial, lo contable ni lo médico.
  #
  # QUÉ NO SE COPIA, a propósito: tareas, auditorías, alertas (se regeneran solas), contabilidad,
  # depósitos, pacientes y cuentas corrientes, dispensaciones, reservas, bar, insumos, jornadas,
  # turnos y mails. Nada de eso hace falta para ver funcionar el cultivo, y los pacientes además son
  # datos personales que no tienen por qué viajar a un club de prueba.
  #
  # TRES CAMPOS SON ÚNICOS A NIVEL BASE, no por club, así que se REGENERAN en el destino:
  # `lotes.codigo_qr`, `lotes.codigo_qr_cosecha`, `plants.codigo_qr` y `stocks.codigo_qr`. Copiarlos
  # tal cual revienta contra el índice único.
  #
  # LOS USUARIOS NO SE COPIAN: `users.email` es único global. Se crea un admin en el club destino y
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
        raise ArgumentError, "Ya existe un club con el slug '#{@slug}'. Elegí otro o borrá el anterior."
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
    # registros del club nuevo y no habría de dónde copiar.
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
      # Sin tenant: al crear un club corre `crear_geneticas_default!`, que consulta las genéticas
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

    # `dup` no alcanza: hay que limpiar las claves del club viejo y todo lo que apunte a personas
    # que no viajan.
    def clonar_attrs(registro, salvo: [])
      registro.attributes.except('id', 'created_at', 'updated_at', 'deleted_by_id', *salvo)
    end

    def copiar_sedes(club, datos)
      datos[:sedes].each do |s|
        nueva = Sede.new(clonar_attrs(s, salvo: %w[club_id created_by_id])
                           .merge('club_id' => club.id, 'created_by_id' => @admin.id))
        nueva.save!(validate: false)
        @map[:sedes][s.id] = nueva.id
        @resumen[:sedes] += 1
      end
    end

    def copiar_salas(club, datos)
      datos[:salas].each do |s|
        nueva = Sala.new(clonar_attrs(s, salvo: %w[club_id sede_id created_by_id responsable_id])
                           .merge('club_id' => club.id,
                                  'sede_id' => @map[:sedes][s.sede_id],
                                  'created_by_id' => @admin.id,
                                  'responsable_id' => nil))
        nueva.save!(validate: false)
        @map[:salas][s.id] = nueva.id
        @resumen[:salas] += 1
      end
    end

    def copiar_geneticas(club, datos)
      datos[:geneticas].each do |g|
        nueva = Genetica.new(clonar_attrs(g, salvo: %w[club_id]).merge('club_id' => club.id))
        nueva.save!(validate: false)
        @map[:geneticas][g.id] = nueva.id
        @resumen[:geneticas] += 1
      end
    end

    def copiar_lotes(club, datos)
      datos[:lotes].each do |l|
        attrs = clonar_attrs(l, salvo: %w[club_id sala_id sede_id genetica_id manicurador_id
                                          planta_madre_id lote_origen_id codigo_qr codigo_qr_cosecha])
        nuevo = Lote.new(attrs.merge(
          'club_id'     => club.id,
          'sala_id'     => @map[:salas][l.sala_id],
          'sede_id'     => @map[:sedes][l.sede_id],
          'genetica_id' => @map[:geneticas][l.genetica_id],
          # El manicurador y la planta madre se resuelven aparte (o se sueltan): el primero es una
          # persona que no viaja; la segunda es una planta que todavía no existe en el destino.
          'manicurador_id'  => nil,
          'planta_madre_id' => nil,
          'lote_origen_id'  => nil,
        ))
        # codigo_qr: los genera el before_create al estar en blanco. Son únicos a nivel base.
        nuevo.save!(validate: false)   # los lotes viejos pueden no cumplir validaciones de hoy
        @map[:lotes][l.id] = nuevo.id
        @resumen[:lotes] += 1
      end
      # `lote_origen_id` (desprendimientos) recién se puede resolver con todos los lotes creados.
      datos[:lotes].select(&:lote_origen_id).each do |l|
        Lote.where(id: @map[:lotes][l.id]).update_all(lote_origen_id: @map[:lotes][l.lote_origen_id])
      end
    end

    def copiar_plants(club, datos)
      datos[:plants].each do |p|
        attrs = clonar_attrs(p, salvo: %w[club_id lote_id codigo_qr qr_token])
        nueva = Plant.new(attrs.merge('club_id' => club.id, 'lote_id' => @map[:lotes][p.lote_id],
                                      'codigo_qr' => nil))
        nueva.qr_token = nil if nueva.respond_to?(:qr_token=)
        nueva.save!(validate: false)
        @map[:plants][p.id] = nueva.id
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
        ev = LoteEvento.new(clonar_attrs(e, salvo: %w[club_id lote_id user_id sala_origen_id sala_destino_id])
                              .merge('club_id' => club.id,
                                     'lote_id' => destino,
                                     'user_id' => @admin.id,
                                     'sala_origen_id'  => @map[:salas][e.sala_origen_id],
                                     'sala_destino_id' => @map[:salas][e.sala_destino_id]))
        ev.save!(validate: false)
        @resumen[:eventos] += 1
      end
    end

    def copiar_plant_activities(datos)
      datos[:activities].each do |a|
        attrs = clonar_attrs(a, salvo: %w[plant_id user_id])
                  .merge('plant_id' => @map[:plants][a.plant_id])
        attrs['user_id'] = @admin.id if a.respond_to?(:user_id)
        PlantActivity.new(attrs).save!(validate: false)
        @resumen[:actividades] += 1
      end
    end

    def copiar_registros_ambientales(club, datos)
      datos[:registros].each do |r|
        nuevo = RegistroAmbiental.new(clonar_attrs(r, salvo: %w[club_id lote_id user_id])
                                        .merge('club_id' => club.id,
                                               'lote_id' => @map[:lotes][r.lote_id],
                                               'user_id' => @admin.id))
        # Sin el callback: las lecturas se copian tal cual del origen, con su sala y su fecha. Si se
        # dejara propagar, se generarían de nuevo con la fecha de hoy y la sala actual.
        nuevo.save!(validate: false)
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
                         # El registro de origen quedó en el club viejo: se corta el puntero en vez
                         # de apuntar a un id ajeno.
                         'origen_record_id' => nil)
        next unless attrs['sala_id']
        LecturaAmbiental.new(attrs).save!(validate: false)
        @resumen[:lecturas] += 1
      end
    end

    def copiar_pesadas(datos)
      datos[:pesadas].each do |p|
        nueva = Pesada.new(clonar_attrs(p, salvo: %w[lote_id registrado_por_id])
                             .merge('lote_id' => @map[:lotes][p.lote_id],
                                    'registrado_por_id' => @admin.id))
        nueva.save!(validate: false)
        @map[:pesadas][p.id] = nueva.id
        @resumen[:pesadas] += 1
      end
    end

    def copiar_pesajes_manicura(club, datos)
      datos[:pesajes].each do |p|
        nuevo = PesajeManicura.new(clonar_attrs(p, salvo: %w[club_id lote_id manicurador_id confirmado_por_id])
                                     .merge('club_id' => club.id,
                                            'lote_id' => @map[:lotes][p.lote_id],
                                            'manicurador_id' => @admin.id,
                                            'confirmado_por_id' => @admin.id))
        nuevo.save!(validate: false)
        @resumen[:pesajes_manicura] += 1
      end
    end

    def copiar_stocks(club, datos)
      datos[:stocks].each do |s|
        attrs = clonar_attrs(s, salvo: %w[club_id lote_id sede_id codigo_qr])
                  .merge('club_id' => club.id,
                         'lote_id' => @map[:lotes][s.lote_id],
                         'sede_id' => @map[:sedes][s.sede_id],
                         'codigo_qr' => nil)
        nuevo = Stock.new(attrs)
        nuevo.save!(validate: false)
        @resumen[:stocks] += 1
      end
    end
  end
end
