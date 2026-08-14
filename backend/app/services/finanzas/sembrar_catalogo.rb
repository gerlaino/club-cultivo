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

    def sembrar_arbol
      cultivo = @unidades['cultivo']
      disp    = @unidades['dispensario']
      admin   = @unidades['administracion']

      # ── Egresos ──────────────────────────────────────────────
      insumos = madre('Insumos', 'egreso', cultivo, comportamiento: 'insumo', clave: 'insumo')
      sub(insumos, 'Fertilizante')
      sub(insumos, 'Sustrato')
      sub(insumos, 'Macetas')
      sub(insumos, 'Semillas')
      sub(insumos, 'Sanidad vegetal')

      servicios = madre('Servicios', 'egreso', cultivo)
      sub(servicios, 'Electricidad', clave: 'electricidad')
      sub(servicios, 'Agua',         clave: 'agua')

      personal = madre('Personal', 'egreso', admin, clave: 'sueldo')
      sub(personal, 'Sueldos')
      sub(personal, 'Honorarios', clave: 'honorario')

      operacion = madre('Operación', 'egreso', admin)
      sub(operacion, 'Alquiler',       clave: 'alquiler')
      sub(operacion, 'Mantenimiento',  clave: 'mantenimiento')
      sub(operacion, 'Seguro',         clave: 'seguro')
      sub(operacion, 'Administrativo', clave: 'admin')

      # Insumos generales del club (se stockean en el depósito general de la sede).
      generales = madre('Insumos generales', 'egreso', admin, comportamiento: 'insumo_general')
      sub(generales, 'Limpieza')
      sub(generales, 'Descartables')
      sub(generales, 'Librería / Oficina')

      madre('Otro', 'egreso', nil, clave: 'otro')

      # ── Ingresos ─────────────────────────────────────────────
      madre('Aportes de socios',     'ingreso', disp,  clave: 'aporte_socio')
      madre('Recupero dispensación', 'ingreso', disp,  clave: 'dispensacion')
      madre('Subvenciones',          'ingreso', admin, clave: 'subvencion')

      # ── Bar (si el feature está activo) ──────────────────────
      if @club.feature?(:bar) && @unidades['bar']
        madre('Mercadería bar', 'egreso', @unidades['bar'], comportamiento: 'mercaderia')
        madre('Venta bar',      'ingreso', @unidades['bar'])
      end
    end

    # Categoría madre (nivel 1). Si trae `clave`, reutiliza la fila plana existente (siembra vieja)
    # y la promueve a madre — así conserva el vínculo con los movimientos. Idempotente.
    def madre(nombre, tipo, unidad, comportamiento: 'general', clave: nil)
      cat = buscar(clave: clave, nombre: nombre, parent_id: nil)
      cat.assign_attributes(nombre: nombre, tipo: tipo, unidad_negocio: unidad, parent_id: nil,
                            comportamiento: comportamiento, es_sistema: true)
      cat.clave_sistema ||= clave
      cat.activa = true if cat.new_record?
      cat.save!
      cat
    end

    # Subcategoría (nivel 2) bajo `madre`. Hereda tipo/comportamiento/unidad de la madre.
    def sub(madre, nombre, clave: nil)
      cat = buscar(clave: clave, nombre: nombre, parent_id: madre.id)
      cat.assign_attributes(nombre: nombre, tipo: madre.tipo, parent: madre, es_sistema: true)
      cat.clave_sistema ||= clave
      cat.activa = true if cat.new_record?
      cat.save!
      cat
    end

    # Reutiliza por clave_sistema (fila existente aunque haya cambiado de nombre/lugar); si no,
    # por nombre + nivel. Evita duplicados al re-sembrar y al actualizar catálogos viejos.
    def buscar(clave:, nombre:, parent_id:)
      return @club.categorias_contables.find_or_initialize_by(clave_sistema: clave) if clave.present?

      @club.categorias_contables.find_or_initialize_by(nombre: nombre, parent_id: parent_id)
    end
  end
end
