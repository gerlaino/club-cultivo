module Finanzas
  # Siembra (y actualiza) las unidades de negocio y el árbol de categorías contables de un club.
  # Idempotente y "upgrade-friendly": si el club ya tenía categorías planas (siembra vieja), las
  # reorganiza bajo sus madres reutilizando la MISMA fila (por clave_sistema) — así no se pierde
  # el vínculo con los movimientos existentes ni se duplican categorías.
  #
  #   Finanzas::SembrarCatalogo.new(club).call
  class SembrarCatalogo
    # Los cinco sectores y nada más (UnidadNegocio::CANONICOS). Antes eran tres + Bar, y el admin
    # podía crear los suyos: cada área nueva arrastraba otro depósito al mismo sector.
    UNIDADES     = UnidadNegocio::CANONICOS.except('bar').freeze
    UNIDADES_BAR = { 'bar' => UnidadNegocio::CANONICOS['bar'] }.freeze

    def initialize(club)
      @club = club
    end

    # El club arranca CON el árbol de categorías puesto.
    #
    # Antes arrancaba en limpio, con la idea de que cada club armara las suyas. En la práctica
    # eso significa que el primer gasto se carga contra un combo vacío: hay que inventar una
    # taxonomía contable en el momento, movimiento por movimiento, y cada persona la inventa
    # distinta. El resultado es que después no se puede filtrar nada ni sacar un informe que
    # cierre — que es exactamente para lo que existen las categorías.
    #
    # Con el árbol puesto, cargar es ELEGIR de una lista y los informes tienen datos
    # consistentes desde el primer día. El club renombra, agrega o desactiva lo que no le
    # sirva; eso es mucho más barato que diseñar un plan de cuentas desde cero.
    def call(con_arbol: true)
      ActsAsTenant.with_tenant(@club) do
        @unidades = sembrar_unidades
        sembrar_arbol if con_arbol
      end
      true
    end

    private

    # Nombres viejos que se renombran solos al pasar a los sectores canónicos. Sólo pisa el
    # nombre si sigue siendo el default anterior: si la organización lo renombró, se respeta.
    RENOMBRES = { 'bar' => { 'Bar' => 'Buffet' } }.freeze

    def sembrar_unidades
      defs = UNIDADES.dup
      defs.merge!(UNIDADES_BAR) if @club.feature?(:bar)
      result = {}
      defs.each_with_index do |(tipo, nombre), i|
        # Se busca POR TIPO, no por (tipo, nombre). Buscando por los dos, una organización que
        # renombró su sector se llevaba uno nuevo con el nombre viejo en la próxima siembra: dos
        # "Cultivo" y dos depósitos para el mismo sector.
        unidad = @club.unidades_negocio
                      .create_with(nombre: nombre, orden: i, es_sistema: true, activa: true)
                      .find_or_create_by!(tipo: tipo)

        if (nuevo = RENOMBRES.dig(tipo, unidad.nombre))
          unidad.update!(nombre: nuevo)
        end
        result[tipo] = unidad
      end
      result
    end

    # UN SOLO NIVEL: sector → categoría. Antes había un escalón intermedio (Insumos › Fertilizante)
    # que había que entender antes de poder anotar un gasto, y los nombres útiles eran las hojas.
    # Ahora las hojas SON las categorías, cada una con su sector y con su destino de stock.
    #
    # Cada categoría es lo que después maneja el alta del movimiento: de acá salen el sector y si
    # la compra entra a un depósito (y a cuál, vía el sector). Por eso vale la pena que el club
    # arranque con una lista razonable en vez de un combo vacío: cargar es ELEGIR, y los informes
    # tienen datos consistentes desde el primer día.
    def sembrar_arbol
      cultivo = @unidades['cultivo']
      disp    = @unidades['dispensario']
      admin   = @unidades['administracion']
      otro    = @unidades['otro']

      # ── Egresos de cultivo: lo que entra al depósito de Cultivo ──
      %w[Fertilizante Sustrato Macetas Semillas].each { |n| cat(n, 'egreso', cultivo, comportamiento: 'insumo') }
      cat('Sanidad vegetal', 'egreso', cultivo, comportamiento: 'insumo')

      # Servicios del cuarto: no stockean.
      cat('Electricidad', 'egreso', cultivo, clave: 'electricidad')
      cat('Agua',         'egreso', cultivo, clave: 'agua')

      # ── Egresos de la organización ──
      cat('Sueldos',        'egreso', admin, clave: 'sueldo')
      cat('Honorarios',     'egreso', admin, clave: 'honorario')
      cat('Alquiler',       'egreso', admin, clave: 'alquiler')
      cat('Mantenimiento',  'egreso', admin, clave: 'mantenimiento')
      cat('Seguro',         'egreso', admin, clave: 'seguro')
      cat('Administrativo', 'egreso', admin, clave: 'admin')

      # Insumos generales: van al depósito General de la sede.
      %w[Limpieza Descartables].each { |n| cat(n, 'egreso', admin, comportamiento: 'insumo_general') }
      cat('Librería / Oficina', 'egreso', admin, comportamiento: 'insumo_general')

      cat('Otro', 'egreso', otro, clave: 'otro')

      # ── Ingresos ─────────────────────────────────────────────
      # No se cargan por "Nuevo movimiento" (ver el modal): las crea el sistema desde la cuenta
      # corriente y la dispensación, o el alta de ingreso excepcional.
      cat('Aportes de socios',     'ingreso', disp,  clave: 'aporte_socio')
      cat('Recupero dispensación', 'ingreso', disp,  clave: 'dispensacion')
      cat('Subvenciones',          'ingreso', admin, clave: 'subvencion')
      cat('Donaciones',            'ingreso', admin)
      cat('Venta de un bien',      'ingreso', otro)

      # ── Buffet (si el add-on está activo) ──
      if @club.feature?(:bar) && @unidades['bar']
        cat('Mercadería buffet', 'egreso',  @unidades['bar'], comportamiento: 'mercaderia')
        cat('Venta buffet',      'ingreso', @unidades['bar'])
      end
    end

    # Categoría de primer (y único) nivel. Si trae `clave`, reutiliza la fila existente —así
    # conserva el vínculo con los movimientos ya cargados— y la sube a nivel raíz si estaba
    # colgando de una madre.
    def cat(nombre, tipo, unidad, comportamiento: 'general', clave: nil)
      registro = buscar(clave: clave, nombre: nombre, parent_id: nil)
      registro.assign_attributes(nombre: nombre, tipo: tipo, unidad_negocio: unidad,
                                 parent_id: nil, comportamiento: comportamiento, es_sistema: true)
      registro.clave_sistema ||= clave
      registro.activa = true if registro.new_record?
      registro.save!
      registro
    end

    def buscar(clave:, nombre:, parent_id:)
      return @club.categorias_contables.find_or_initialize_by(clave_sistema: clave) if clave.present?

      @club.categorias_contables.find_or_initialize_by(nombre: nombre, parent_id: parent_id)
    end
  end
end
