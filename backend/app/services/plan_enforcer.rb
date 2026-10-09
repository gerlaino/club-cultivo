class PlanEnforcer
  # El plan dice CUÁNTO, nunca QUÉ. Qué módulos tiene una organización se decide aparte, en
  # `Club::SUITES` / `Club::ADDONS`: mezclar las dos cosas era lo que hacía que una organización
  # "federación" quedara sin límites y sin poder hacer nada.
  #
  # `nil` = sin límite.
  #
  # `lotes` NO se limita a propósito. El lote es una unidad de ORGANIZACIÓN, no de capacidad:
  # limitarlo empuja al club a meter todo en un lote gigante para no chocar el tope, y eso
  # rompe la trazabilidad, que es el activo del producto. Lo que mide la capacidad real del
  # cultivo son las plantas.
  #
  # `usuarios` tampoco es un número: pasó a ser UNO POR ROL en el plan Básico (ver
  # `usuarios_por_rol`). Un tope global no decía nada —"5 usuarios" no se puede vender ni
  # explicar— y dejaba dar de alta cinco cultivadores y ningún dispensador.
  #
  # `personal` es el AUTOCULTIVO: una persona, un espacio, dos salas a lo sumo, sin pacientes y
  # SIN EQUIPO. `equipo: false` es lo que lo distingue de una organización chica: no es que tenga
  # pocos usuarios, es que no hay nadie más que él. Lo único que rompe la regla de «el plan dice
  # CUÁNTO, nunca QUÉ» es que además acota los módulos a Cultivo — y ese candado vive en el
  # controller del super admin, no acá (`Club::MODULOS_PERSONAL`).
  #
  # LOS ESCALONES (6-oct-2026, Germán y su socio). Los packs cobran por TAMAÑO:
  #
  #   personal → Autocultivo: 9 plantas en floración, 2 espacios.
  #   basico   → Hasta 50 pacientes: 450 plantas en floración, 3 salas, 1 sede, 2 usuarios por rol.
  #   total    → Hasta 100 pacientes: 900 en floración, salas libres, 3 sedes, 2 usuarios por rol
  #              EN CADA SEDE.
  #
  # Arriba del escalón se compran packs de 10 pacientes (cada uno suma 10 pacientes y 90 plantas
  # en floración: las 9 por paciente del REPROCANN) y sedes extra. Esas cantidades viven en el
  # club (`packs_pacientes_extra`, `sedes_extra`) y se suman acá: ver `limite`.
  #
  # `plantas` cuenta las que están EN FLORACIÓN (el vegetativo es libre), y las de una genética
  # AUTOMÁTICA cuentan todo su ciclo, porque nunca pasan a «floración» en la app (se cosechan
  # desde vegetativo). Es un CANDADO, también en el autocultivo (6-oct-2026: antes era un aviso).
  # Ver `plantas_en_cupo`.
  #
  # `fotos` mide almacenamiento, que se paga por GB guardado y bajado. Números provisorios.
  PLANES = {
    'basico'   => { label: 'Hasta 50 pacientes',  sedes: 1, salas: 3,   lotes: nil, plantas: 450, pacientes: 50,  usuarios: nil, fotos: 1_000, usuarios_por_rol: 2,   por_sede: false, equipo: true  },
    'total'    => { label: 'Hasta 100 pacientes', sedes: 3, salas: nil, lotes: nil, plantas: 900, pacientes: 100, usuarios: nil, fotos: 3_000, usuarios_por_rol: 2,   por_sede: true,  equipo: true  },
    'personal' => { label: 'Autocultivo',         sedes: 1, salas: 2,   lotes: nil, plantas: 9,   pacientes: 0,   usuarios: nil, fotos: 300,   usuarios_por_rol: nil, por_sede: false, equipo: false },
  }.freeze

  # Un pack de pacientes extra: cuántos pacientes suma y cuántas plantas en floración por cada uno.
  PACK_PACIENTES       = 10
  PLANTAS_POR_PACIENTE = 9

  # Los estados en los que una planta está viva en el cultivo.
  ESTADOS_EN_PIE = %w[enraizado vegetativo floracion].freeze

  # Tamaño máximo de UNA foto. El teléfono ya la achica antes de subir (`lib/imagenes.js`, a
  # ~250 KB); esto es la red para lo que llega por otra puerta.
  FOTO_MAX_BYTES = 8.megabytes

  PLAN_POR_DEFECTO = 'basico'.freeze

  # Los cuatro planes viejos, mapeados a los dos nuevos. La migración de datos reescribe la
  # columna, pero una organización con el valor viejo (una copia vieja, un seed) no puede quedar sin
  # límites por accidente: cae al que le corresponde en vez de a `PLANES[nil]`.
  PLANES_LEGACY = {
    'semilla'    => 'basico',
    'brote'      => 'basico',
    'cosecha'    => 'total',
    'federacion' => 'total',
  }.freeze

  # Qué se limita, en el orden en que se le muestra al super admin.
  RECURSOS = %i[sedes salas lotes plantas pacientes usuarios fotos].freeze

  # A qué suite le importa cada tope. Sirve para no nombrarle salas y plantas a una organización
  # que no compró Cultivo: el alta elige los módulos ANTES que el plan, así que se puede mostrar
  # sólo lo que aplica. `nil` = le importa a cualquiera.
  RECURSO_SUITE = {
    sedes:     nil,
    salas:     'cultivo',
    lotes:     'cultivo',
    plantas:   'cultivo',
    pacientes: 'produccion_dispensa',
    usuarios:  nil,
    fotos:     'cultivo',
  }.freeze

  # Normaliza cualquier valor guardado en `clubs.plan` a uno de los dos planes vigentes.
  def self.normalizar(plan)
    p = plan.to_s
    return p if PLANES.key?(p)
    PLANES_LEGACY[p] || PLAN_POR_DEFECTO
  end

  def initialize(club)
    @club   = club
    @plan   = self.class.normalizar(club.plan)
    @base   = PLANES[@plan]
    @limite = RECURSOS.to_h { |r| [r, limite(r)] }.merge(@base.slice(:label, :usuarios_por_rol, :por_sede, :equipo))
  end

  # El tope EFECTIVO de un recurso: el del escalón más lo que la organización compró encima
  # (packs de pacientes y sedes extra). El autocultivo no compra extras.
  def limite(recurso)
    base = @base[recurso]
    return base if base.nil? || personal?

    case recurso
    when :pacientes then base + packs_pacientes * PACK_PACIENTES
    when :plantas   then base + packs_pacientes * PACK_PACIENTES * PLANTAS_POR_PACIENTE
    when :sedes     then base + @club.sedes_extra.to_i
    else base
    end
  end

  def packs_pacientes = @club.packs_pacientes_extra.to_i

  def puede_crear_sede?
    return true if @limite[:sedes].nil?
    sedes_vigentes < @limite[:sedes]
  end

  # Sin este límite, una organización de una sola sede podía abrir salas sin techo: el plan medía el
  # continente y no el contenido.
  #
  # Cuenta las salas que EXISTEN, no las que están en uso: una sala en mantenimiento sigue
  # siendo de la organización y vuelve mañana. Contar sólo `activas` habría dejado abrir salas sin techo
  # poniéndolas todas en mantenimiento. Sólo la sala cerrada —dada de baja— libera lugar.
  def puede_crear_sala?
    return true if @limite[:salas].nil?
    salas_vigentes < @limite[:salas]
  end

  def puede_crear_lote?
    return true if @limite[:lotes].nil?
    @club.lotes.count < @limite[:lotes]
  end

  # ── Plantas en floración ─────────────────────────────────────────────────
  #
  # Las plantas que ocupan cupo: en floración, o vivas de un lote de genética automática (que no
  # pasa nunca a «floración» en la app). `excluir_lote` deja afuera las de un lote, para poder
  # preguntar «¿cabe este lote entero?» sin importar si sus plantas ya cambiaron de estado o no
  # (`Salas::CambiarFase` mueve las plantas ANTES que el lote).
  def plantas_en_cupo(excluir_lote: nil)
    scope = Plant.joins(:lote)
                 .joins('LEFT JOIN geneticas ON geneticas.id = lotes.genetica_id')
                 .where(lotes: { club_id: @club.id }, state: ESTADOS_EN_PIE)
                 .where("plants.state = 'floracion' OR geneticas.automatica = TRUE")
    scope = scope.where.not(lote_id: excluir_lote.id) if excluir_lote
    scope.count
  end

  # De qué está hecho el cupo, para decirlo en pantalla (9-oct-2026: «En floración 6 de 9» con tres
  # automáticas en vege se leía como un error). Suma `plantas_en_cupo`.
  def plantas_en_cupo_desglose
    base = Plant.joins(:lote).joins('LEFT JOIN geneticas ON geneticas.id = lotes.genetica_id')
                .where(lotes: { club_id: @club.id }, state: ESTADOS_EN_PIE)
    en_flora = base.where(state: 'floracion').count
    autos    = base.where.not(state: 'floracion').where(geneticas: { automatica: true }).count
    { en_floracion: en_flora, automaticas: autos }
  end

  # ¿Entran `cantidad` plantas más al cupo de floración?
  def cabe_en_floracion?(cantidad, excluir_lote: nil)
    tope = @limite[:plantas]
    return true if tope.nil? || cantidad.to_i <= 0

    plantas_en_cupo(excluir_lote: excluir_lote) + cantidad.to_i <= tope
  end

  # ¿Cuántas más entran? nil = sin tope.
  def lugar_en_floracion
    tope = @limite[:plantas]
    tope && [tope - plantas_en_cupo, 0].max
  end

  # El mensaje de quien choca el tope de floración: qué plan, cuál es el tope y qué hacer.
  def error_floracion(querian = nil, excluir_lote: nil)
    tope  = @limite[:plantas]
    hay   = plantas_en_cupo(excluir_lote: excluir_lote)
    plan  = @limite[:label]
    salida = personal? ? 'Para florecer más plantas hay que cosechar o descartar alguna.' \
                       : 'Para sumar más, hay que ampliar el plan: escribinos y lo cambiamos.'
    detalle = querian ? " y este paso suma #{querian}" : ''
    msg = "El plan #{plan} permite #{tope} plantas en floración. Hoy hay #{hay}#{detalle}. #{salida}"
    { error: 'limite_plan', errors: [msg], mensaje: msg, recurso: 'plantas', limite: tope,
      plan: plan, upgrade: !personal? }
  end

  # Una foto más, de lote, sala o planta: las tres cuentan contra el mismo techo.
  def puede_subir_foto?
    return true if @limite[:fotos].nil?
    fotos_usadas < @limite[:fotos]
  end

  def fotos_usadas
    lotes    = LoteFoto.where(club_id: @club.id).count
    salas    = ActiveStorage::Attachment.where(record_type: 'Sala', name: 'fotos', record_id: @club.salas.select(:id)).count
    plantas  = ActiveStorage::Attachment.where(record_type: 'Plant', name: 'fotos',
                                               record_id: Plant.joins(:lote).where(lotes: { club_id: @club.id }).select(:id)).count
    lotes + salas + plantas
  end

  # Qué le queda de fotos, para que la pantalla lo diga antes de abrir la cámara.
  def cupo_fotos
    { usadas: fotos_usadas, tope: @limite[:fotos] }
  end

  def puede_crear_paciente?
    return true if @limite[:pacientes].nil?
    @club.pacientes.count < @limite[:pacientes]
  end

  # El cupo de usuarios es POR ROL, no un número global.
  #
  # `del_equipo`: el cupo es del EQUIPO. Los pacientes tienen cuenta para su portal y ya
  # gastan su propio límite (`pacientes`); contándolos acá se cobraban dos veces y un club
  # Básico se quedaba sin poder dar de alta empleados al quinto paciente con portal.
  #
  # En Básico va uno de cada rol: un cultivador, un dispensador, un médico. En Total, los que
  # necesite. Qué roles puede tener depende de los módulos contratados y eso lo decide
  # `Club#roles_para_alta`, que es otra pregunta: acá sólo se cuenta CUÁNTOS de ese rol.
  def puede_crear_usuario?(rol = nil)
    # Sin equipo no entra nadie más, tampoco otro admin: en el uso personal la cuenta ES la
    # persona.
    return false unless equipo?

    tope = tope_por_rol
    return true if tope.nil?
    # Sin rol no hay nada que contar. Que el rol sea válido lo valida el controller, que además
    # es el único que sabe si se puede asignar en esta organización.
    return true if rol.blank?
    return true if ROLES_SIN_TOPE.include?(rol.to_s)

    usuarios_de_rol(rol) < tope
  end

  # El admin queda FUERA del cupo por rol. No es un puesto de trabajo: es quien contrata, y son
  # dos socios más veces de las que es uno solo. Con tope de uno, un club de dos dueños no puede
  # darle acceso al segundo, y el día que el único admin se va hay que meter mano en la base
  # para devolverle el control a alguien — un tope que sólo se puede levantar desde adentro no
  # es un tope, es un incidente.
  ROLES_SIN_TOPE = %w[admin].freeze

  def usuarios_de_rol(rol) = @club.users.del_equipo.where(role: rol.to_s).count

  def usuarios_por_rol = @limite[:usuarios_por_rol]

  # Cuántos de un mismo rol puede tener HOY. En «Hasta 100 pacientes» el cupo es por sede: dos de
  # cada rol en cada sede que tenga abierta. Se cuenta contra el total de la organización (dos por
  # sede, por la cantidad de sedes) y no sede por sede, porque un usuario puede estar en varias
  # sedes o en ninguna (= en todas).
  def tope_por_rol
    tope = @limite[:usuarios_por_rol]
    return nil if tope.nil?
    return tope unless @limite[:por_sede]

    tope * [sedes_vigentes, 1].max
  end

  # ¿El plan admite más gente que quien lo contrató?
  def equipo? = @limite[:equipo] != false

  def personal? = @plan == 'personal'

  def info
    {
      plan:         @plan,
      label:        @limite[:label],
      trial:        @club.plan_trial,
      activo_hasta: @club.plan_activo_hasta,
      limites:      RECURSOS.to_h { |r| [r, @limite[r]] },
      # Aparte de los topes numéricos: el de usuarios no es un número, es "dos de cada rol".
      # Va suelto para que la pantalla lo pueda decir con palabras en vez de con una barra.
      usuarios_por_rol: @limite[:usuarios_por_rol],
      # De qué está hecho el uso de `plantas` (va suelto: `uso` son sólo los recursos con tope).
      plantas_desglose: plantas_en_cupo_desglose,
      usuarios_por_rol_hoy: tope_por_rol,
      por_sede:     @limite[:por_sede],
      # Lo comprado encima del escalón.
      packs_pacientes_extra: personal? ? 0 : packs_pacientes,
      sedes_extra:  personal? ? 0 : @club.sedes_extra.to_i,
      # `false` = la cuenta es de una sola persona: la pantalla esconde «Equipo» entero en vez
      # de mostrar un formulario que el backend va a rechazar.
      equipo:       equipo?,
      personal:     personal?,
      uso:          uso,
    }
  end

  def salas_vigentes = @club.salas.where.not(state: 'cerrada').count

  # Cuenta las sedes que EXISTEN, no las que están en uso — el mismo criterio que las salas, que
  # ya lo tenía. Con `activas` alcanzaba con desactivar la sede para liberar el cupo y crear
  # otra: una organización del plan Básico podía tener las sedes que quisiera creando, apagando
  # y volviendo a prender. Sólo borrarla libera lugar.
  def sedes_vigentes = @club.sedes.count

  def uso
    {
      sedes:     sedes_vigentes,
      salas:     salas_vigentes,
      lotes:     @club.lotes.count,
      plantas:   plantas_en_cupo,
      pacientes: @club.pacientes.count,
      usuarios:  @club.users.del_equipo.count,
      fotos:     fotos_usadas,
    }
  end

  # El mensaje que ve quien se choca contra el tope. Tiene que decir tres cosas —qué plan
  # tenés, cuál es el tope y qué hacer— porque el usuario que lo lee no eligió el plan y no
  # tiene forma de averiguarlo desde donde está parado. "Límite del plan alcanzado" a secas
  # deja a alguien mirando un formulario que no guarda, sin saber si es un error o una regla.
  def self.error_limite(recurso, limite, plan: nil)
    plan_txt = plan.present? ? "El plan #{plan}" : 'Tu plan'
    msg = if limite
            "#{plan_txt} permite hasta #{limite} #{recurso}, y la organización ya llegó a ese número. " \
            'Para dar de alta más, hay que ampliar el plan: escribinos y lo cambiamos.'
          else
            "#{plan_txt} no incluye #{recurso}. Escribinos y lo habilitamos."
          end
    { error: 'limite_plan', errors: [msg], mensaje: msg, recurso: recurso.to_s, limite: limite,
      plan: plan, upgrade: true }
  end

  # El tope de usuarios no es un número, así que su mensaje tampoco puede serlo: "permite hasta
  # 1 usuarios" no se entiende. Tiene que nombrar el ROL, que es lo que la persona estaba
  # tratando de dar de alta, y decir la salida.
  def self.error_limite_rol(rol, plan: nil, tope: 2)
    label    = Club::ROLES_META.dig(rol.to_s, :label) || rol.to_s
    plan_txt = plan.present? ? "El plan #{plan}" : 'Tu plan'
    # Sin equipo el mensaje no puede hablar de cupos: no es que se llenó, es que no hay.
    if tope.nil?
      msg = "#{plan_txt} es para una sola persona: no se puede sumar a nadie más. " \
            'Si tu cultivo creció y necesitás equipo, escribinos y lo pasamos a un plan de organización.'
      return { error: 'limite_plan', errors: [msg], mensaje: msg, recurso: 'usuarios', rol: rol.to_s,
               limite: 0, plan: plan, upgrade: true }
    end
    msg = "#{plan_txt} incluye #{tope == 1 ? 'un' : tope} #{label.downcase}#{tope == 1 ? '' : 's'} " \
          "y la organización ya #{tope == 1 ? 'lo tiene' : 'los tiene'}. " \
          'Para sumar otro hay que ampliar el plan: escribinos y lo cambiamos.'
    { error: 'limite_plan', errors: [msg], mensaje: msg, recurso: 'usuarios', rol: rol.to_s,
      limite: tope, plan: plan, upgrade: true }
  end
end
