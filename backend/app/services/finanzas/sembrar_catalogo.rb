module Finanzas
  # Siembra las unidades de negocio y categorías contables "de sistema" de un club a partir
  # de los enums legacy (MovimientoContable::CATEGORIAS/LABELS). Idempotente: se puede correr
  # muchas veces sin duplicar (find_or_create_by por club + clave). Se invoca la primera vez
  # que el club entra a Finanzas y al activar el flag de bar (para sumar su unidad).
  #
  #   Finanzas::SembrarCatalogo.new(club).call
  class SembrarCatalogo
    # tipo de unidad => nombre visible
    UNIDADES = {
      'cultivo'        => 'Cultivo',
      'dispensario'    => 'Dispensario',
      'administracion' => 'Administración',
    }.freeze

    UNIDADES_BAR = {
      'bar' => 'Bar',
    }.freeze

    # clave_sistema => [tipo_categoria, tipo_unidad]. Deriva de los enums de MovimientoContable.
    CATEGORIAS = {
      'insumo'        => ['egreso',  'cultivo'],
      'electricidad'  => ['egreso',  'cultivo'],
      'agua'          => ['egreso',  'cultivo'],
      'alquiler'      => ['egreso',  'administracion'],
      'sueldo'        => ['egreso',  'administracion'],
      'mantenimiento' => ['egreso',  'administracion'],
      'honorario'     => ['egreso',  'administracion'],
      'seguro'        => ['egreso',  'administracion'],
      'admin'         => ['egreso',  'administracion'],
      'aporte_socio'  => ['ingreso', 'dispensario'],
      'dispensacion'  => ['ingreso', 'dispensario'],
      'subvencion'    => ['ingreso', 'administracion'],
      'otro'          => ['egreso',  nil],
    }.freeze

    def initialize(club)
      @club = club
    end

    def call
      ActsAsTenant.with_tenant(@club) do
        unidades = sembrar_unidades
        sembrar_categorias(unidades)
        sembrar_categorias_bar(unidades['bar']) if @club.feature?(:bar) && unidades['bar']
      end
      true
    end

    private

    def sembrar_unidades
      defs = UNIDADES.dup
      defs.merge!(UNIDADES_BAR) if @club.feature?(:bar)

      result = {}
      defs.each_with_index do |(tipo, nombre), i|
        result[tipo] = @club.unidades_negocio.create_with(
          nombre: nombre, orden: i, es_sistema: true, activa: true
        ).find_or_create_by!(tipo: tipo, nombre: nombre)
      end
      result
    end

    def sembrar_categorias(unidades)
      CATEGORIAS.each_with_index do |(clave, (tipo_cat, tipo_unidad)), i|
        label   = MovimientoContable::CATEGORIA_LABELS[clave] || clave.humanize
        unidad  = tipo_unidad && unidades[tipo_unidad]
        @club.categorias_contables.create_with(
          nombre: label, tipo: tipo_cat, unidad_negocio: unidad,
          orden: i, es_sistema: true, activa: true
        ).find_or_create_by!(clave_sistema: clave)
      end
    end

    # Categorías propias del bar. Sin clave_sistema (no mapean a la lógica legacy):
    # el string `categoria` del movimiento cae en 'otro', y el eje real es la unidad Bar.
    def sembrar_categorias_bar(unidad_bar)
      [['Venta bar', 'ingreso'], ['Mercadería bar', 'egreso']].each do |nombre, tipo_cat|
        @club.categorias_contables.create_with(
          tipo: tipo_cat, unidad_negocio: unidad_bar, es_sistema: true, activa: true
        ).find_or_create_by!(nombre: nombre)
      end
    end
  end
end
